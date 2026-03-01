FROM jenkins/jenkins:lts

USER root
RUN apt-get update && apt-get install -y curl unzip \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL "https://github.com/runpod/runpodctl/releases/download/v1.14.3/runpodctl-linux-amd64" -o /usr/local/bin/runpodctl \
    && chmod +x /usr/local/bin/runpodctl \
    && curl -fsSL "https://releases.hashicorp.com/terraform/1.10.3/terraform_1.10.3_linux_amd64.zip" -o /tmp/terraform.zip \
    && unzip /tmp/terraform.zip -d /usr/local/bin \
    && rm /tmp/terraform.zip
USER jenkins

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
