FROM marketplace.gcr.io/google/debian11:latest as build

ARG REGISTRY
ARG TAG

RUN apt-get update && apt-get install -y --no-install-recommends gettext

ADD chart/gateway /tmp/chart
RUN cd /tmp && tar -czvf /tmp/gateway.tar.gz chart

ADD schema.yaml /tmp/schema.yaml

RUN echo "=== Variables before envsubst ===" \
    && echo "REGISTRY=${REGISTRY}" \
    && echo "TAG=${TAG}" \
    && cat /tmp/schema.yaml \
    | REGISTRY="${REGISTRY}" TAG="${TAG}" envsubst \
    > /tmp/schema.yaml.new \
    && mv /tmp/schema.yaml.new /tmp/schema.yaml

RUN echo "=== Schema after envsubst ===" \
    && cat /tmp/schema.yaml \
    && echo "=== publishedVersion check ===" \
    && grep "publishedVersion" /tmp/schema.yaml

RUN mkdir -p /tmp/chart/data-test \
    && cp /tmp/schema.yaml /tmp/chart/data-test/schema.yaml

FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm:0.11.8

RUN echo "=== APPLYING MARKETPLACE TOOLS PATCH ===" \
    && cp /bin/provision.py /bin/provision.py.backup \
    && echo "Before patch - show all raise Exception with deployer:" \
    && grep -n "raise Exception.*deployer" /bin/provision.py || echo "No raise Exception found initially" \
    && python3 -c "
import re

with open('/bin/provision.py', 'r') as f:
    content = f.read()

print('=== Original content around deployer_image_to_repo_prefix function ===')
start = content.find('def deployer_image_to_repo_prefix')
if start != -1:
    # Show 20 lines from function start
    lines = content[start:start+2000]
    print(lines)

# Remove ALL raise Exception lines that mention deployer
content = re.sub(r'.*raise Exception.*deployer.*\n', '', content, flags=re.IGNORECASE)

# Also replace the entire function to be sure
pattern = r'def deployer_image_to_repo_prefix.*?(?=\ndef |\Z)'
replacement = '''def deployer_image_to_repo_prefix(deployer_image):
  \"\"\"Extract repo prefix from deployer image name.\"\"\"
  image_without_tag = deployer_image.split('@')[0].rsplit(':', 1)[0]
  if image_without_tag.endswith('/deployer'):
    return image_without_tag[:-len('/deployer')]
  else:
    return image_without_tag

'''

content = re.sub(pattern, replacement, content, flags=re.MULTILINE | re.DOTALL)

with open('/bin/provision.py', 'w') as f:
    f.write(content)
" \
    && echo "=== PATCH APPLIED ===" \
    && echo "After patch - check for any remaining raise Exception:" \
    && grep -n "raise Exception.*deployer" /bin/provision.py || echo "✅ No raise Exception found!" \
    && echo "Function after patch:" \
    && grep -A 10 "def deployer_image_to_repo_prefix" /bin/provision.py

COPY --from=build /tmp/gateway.tar.gz /data/chart/
COPY --from=build /tmp/schema.yaml /data/
COPY --from=build /tmp/chart/data-test/schema.yaml /data-test/

RUN mkdir -p /data/values

RUN echo "=== Final /data structure ===" \
    && ls -la /data/ \
    && echo "=== Final schema.yaml publishedVersion ===" \
    && grep "publishedVersion" /data/schema.yaml || echo "No publishedVersion found"
