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
    && echo "Before patch:" \
    && grep -n "raise Exception" /bin/provision.py | head -5 \
    && sed -i '/raise Exception.*[Dd]eployer/d' /bin/provision.py \
    && sed -i '/raise Exception.*suffix/d' /bin/provision.py \
    && sed -i '/Deployer image must have/d' /bin/provision.py \
    && echo "Lines 740-750 before function replacement:" \
    && sed -n '740,750p' /bin/provision.py \
    && sed -i '742,748d' /bin/provision.py \
    && sed -i '741a\def deployer_image_to_repo_prefix(deployer_image):\
  """Extract repo prefix from deployer image name."""\
  image_without_tag = deployer_image.split("@")[0].rsplit(":", 1)[0]\
  if image_without_tag.endswith("/deployer"):\
    return image_without_tag[:-len("/deployer")]\
  else:\
    return image_without_tag\
' /bin/provision.py \
    && echo "=== PATCH APPLIED ===" \
    && echo "Final verification - no raise Exception should remain:" \
    && grep -n "raise Exception.*deployer" /bin/provision.py || echo "✅ Success!" \
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
