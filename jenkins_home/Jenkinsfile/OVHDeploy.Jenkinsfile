pipeline {
    agent any
    parameters {
        string(name: 'VM_IP', defaultValue: '', description: 'Publiczny adres IP VM (z outputu terraform)')
        string(name: 'VM_USER', defaultValue: 'ubuntu', description: 'Użytkownik SSH na VM')
        string(name: 'BRANCH', defaultValue: 'main', description: 'Branch do wdrożenia')
    }
    stages {
        stage('Deploy Application') {
            steps {
                withCredentials([
                    string(credentialsId: 'GITHUB_TOKEN', variable: 'GITHUB_TOKEN')
                ]) {
                    script {
                        def branch = params.BRANCH
                        def vmUser = params.VM_USER
                        def vmIp = params.VM_IP
                        def githubToken = env.GITHUB_TOKEN

                        writeFile file: 'ovh_deploy.sh', text: """#!/bin/bash
set -e

echo "Waiting for Docker to be ready..."
until [ -f /var/lib/cloud/instance/docker-ready ]; do
    sleep 5
done

REPO_URL="https://Kruczkowski:${githubToken}@github.com/Kruczkowski/-rememoria.git"

if [ -d rememoria/.git ]; then
    echo "Repository exists, updating..."
    cd rememoria
    git remote set-url origin "\$REPO_URL"
    git fetch origin
    git checkout ${branch}
    git reset --hard origin/${branch}
    cd ..
else
    echo "Cloning repository..."
    rm -rf rememoria
    git clone -b ${branch} "\$REPO_URL" rememoria
fi

cd rememoria
docker compose -f docker-compose.vps.yml up -d --force-recreate

echo "Waiting for containers to be ready..."
until docker compose -f docker-compose.vps.yml exec -T php php -v > /dev/null 2>&1; do
    sleep 5
done

docker compose -f docker-compose.vps.yml exec -T php composer install --no-interaction --prefer-dist --no-progress
docker compose -f docker-compose.vps.yml exec -T php php bin/console doctrine:migrations:migrate --no-interaction

echo "Deploy zakończony sukcesem."
"""

                        sh """
                            SSH_KEY=/var/jenkins_home/.ssh/id_ed25519
                            ssh -o StrictHostKeyChecking=no -o BatchMode=yes \
                                -o ServerAliveInterval=30 -o ServerAliveCountMax=10 \
                                -i \${SSH_KEY} ${vmUser}@${vmIp} \
                                'bash -s' < ovh_deploy.sh
                        """
                    }
                }
            }
        }
    }
    post {
        always {
            sh 'rm -f ovh_deploy.sh'
        }
    }
}
