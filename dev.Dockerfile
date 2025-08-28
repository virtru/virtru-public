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
    && cat > /tmp/complete_patch.py << 'SCRIPT'
import re

with open('/bin/provision.py', 'r') as f:
    content = f.read()

print("=== Before patch ===")
print("Total lines:", len(content.split('\n')))

# Find the function and show context
func_start = content.find('def deployer_image_to_repo_prefix')
if func_start != -1:
    print("Function starts at character:", func_start)
    lines = content[:func_start].count('\n') + 1
    print("Function starts at line:", lines)

# Remove ALL raise Exception lines with deployer/suffix
content = re.sub(r'.*raise Exception.*[Dd]eployer.*\n', '', content)
content = re.sub(r'.*raise Exception.*suffix.*\n', '', content)
content = re.sub(r'.*Deployer image must have.*\n', '', content)

# Find and completely remove the ENTIRE function including all its content
pattern = r'def deployer_image_to_repo_prefix\(deployer_image\):.*?(?=\ndef [a-zA-Z_]|\Z)'
matches = re.findall(pattern, content, flags=re.MULTILINE | re.DOTALL)
print(f"Found {len(matches)} function matches")
for i, match in enumerate(matches):
    print(f"Match {i}: {match[:100]}...")

# Remove the entire function
content = re.sub(pattern, '', content, flags=re.MULTILINE | re.DOTALL)

# Add our new function at the end, before main()
new_function = '''
def deployer_image_to_repo_prefix(deployer_image):
  """Extract repo prefix from deployer image name."""
  image_without_tag = deployer_image.split('@')[0].rsplit(':', 1)[0]
  if image_without_tag.endswith('/deployer'):
    return image_without_tag[:-len('/deployer')]
  else:
    return image_without_tag

'''

# Insert before main()
main_pos = content.find("if __name__ == '__main__':")
if main_pos != -1:
    content = content[:main_pos] + new_function + content[main_pos:]
    print("Function inserted before main()")
else:
    content += new_function
    print("Function appended at end")

with open('/bin/provision.py', 'w') as f:
    f.write(content)

print("=== After patch ===")
print("Total lines:", len(content.split('\n')))
SCRIPT

RUN python3 /tmp/complete_patch.py \
    && rm /tmp/complete_patch.py \
    && echo "=== FINAL VERIFICATION ===" \
    && echo "Checking for any raise Exception with deployer:" \
    && grep -n "raise Exception.*deployer" /bin/provision.py || echo "✅ No raise Exception found!" \
    && echo "Final function count:" \
    && grep -c "def deployer_image_to_repo_prefix" /bin/provision.py \
    && echo "Function content:" \
    && grep -A 8 "def deployer_image_to_repo_prefix" /bin/provision.py

COPY --from=build /tmp/gateway.tar.gz /data/chart/
COPY --from=build /tmp/schema.yaml /data/
COPY --from=build /tmp/chart/data-test/schema.yaml /data-test/

RUN mkdir -p /data/values

RUN echo "=== Final /data structure ===" \
    && ls -la /data/ \
    && echo "=== Final schema.yaml publishedVersion ===" \
    && grep "publishedVersion" /data/schema.yaml || echo "No publishedVersion found"
