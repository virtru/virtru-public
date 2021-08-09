# Virtru for Data Encryption, Protection, and Privacy
for GCP Marketplace

## About this repository
The virtru-public repository supports the deployment of Virtru data protection software through the GCP Marketplace.

## Usage
[Virtru Installation Guide](https://support.virtru.com/hc/en-us/sections/360012614693-Virtru-Gateway-Google-Marketplace) provides Step-by-step instructions 
to complete necessary fields prior to deployment.

## About Virtru
Virtru was founded on the core belief that privacy-preserving data protection is both a fundamental right and a force multiplier for organizations. Our products make it easy to share sensitive data, while you meet compliance, so you can collaborate with confidence and achieve your organizational mission. If you have questions, need support, or require help installing Virtru, please visit our support center.
[Learn more](https://support.virtru.com/hc/en-us)

## Deploying with `mpdev`

To deploy to marketplace using Google's `mpdev` tool, first add the necessary secrets and configs to the `parameters` JSON block in `gke-deploy.sh`. Parameters set here can be used to override the default settings in `chart/gateway/values.yaml`. If deploying to production, set `ENVIRONMENT=production` in your local environment. Then run `./gke-deploy.sh` to deploy.
