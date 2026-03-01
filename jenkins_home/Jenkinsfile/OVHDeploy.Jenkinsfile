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
                    sh '''
                        SSH_KEY=/var/jenkins_home/.ssh/id_ed25519

                        ssh -o StrictHostKeyChecking=no -o BatchMode=yes -T -i ${SSH_KEY} ${VM_USER}@${VM_IP} bash << ENDSSH
                            echo "Waiting for Docker to be ready..."
                            until [ -f /var/lib/cloud/instance/docker-ready ]; do
                                sleep 5
                            done

                            REPO_URL="https://Kruczkowski:${GITHUB_TOKEN}@github.com/Kruczkowski/-rememoria.git"

                            if [ -d rememoria/.git ]; then
                                echo "Repository exists, updating..."
                                cd rememoria
                                git remote set-url origin \${REPO_URL}
                                git fetch origin
                                git checkout ${BRANCH}
                                git reset --hard
                                git pull origin
                                cd ..
                            else
                                echo "Cloning repository..."
                                rm -rf rememoria
                                git clone -b ${BRANCH} \${REPO_URL} rememoria
                            fi

                            cd rememoria
                            docker compose -f docker-compose.vps.yml up -d --force-recreate

                            echo "Waiting for containers to be ready..."
                            until docker compose -f docker-compose.vps.yml exec -T php php -v > /dev/null 2>&1; do
                                sleep 5
                            done

                            docker compose -f docker-compose.vps.yml exec -T php composer install --no-interaction --prefer-dist --no-progress
                            docker compose -f docker-compose.vps.yml exec -T php php bin/console doctrine:migrations:migrate --no-interaction
ENDSSH
                    '''
                }
            }
        }
    }
}
