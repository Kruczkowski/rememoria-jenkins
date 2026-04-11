@NonCPS
def jsonField(String text, String key) {
    return new groovy.json.JsonSlurper().parseText(text)?.get(key)?.toString() ?: ''
}

@NonCPS
def jsonPortMapping(String text, String port) {
    def parsed = new groovy.json.JsonSlurper().parseText(text)
    return parsed?.portMappings?.get(port)?.toString() ?: ''
}

pipeline {
    agent any
    parameters {
        string(name: 'POD_ID', defaultValue: '', description: 'ID poda RunPod')
        string(name: 'OVH_IP', defaultValue: '', description: 'Publiczny adres IP VM OVH (używany w URL-ach)')
        string(name: 'BRANCH', defaultValue: 'main', description: 'Branch do wdrożenia')
        booleanParam(name: 'SETUP_LIVEPORTRAIT', defaultValue: false, description: 'Uruchom skrypt docker/python-base/setup.sh')
    }
    stages {
        stage('Deploy to RunPod') {
            steps {
                withCredentials([
                    string(credentialsId: 'RUNPOD_API_KEY', variable: 'RUNPOD_API_KEY'),
                    string(credentialsId: 'GITHUB_TOKEN', variable: 'GITHUB_TOKEN')
                ]) {
                    script {
                        def podInfo = sh(script: """
                            curl -s "https://rest.runpod.io/v1/pods/${params.POD_ID}" \
                              -H "Authorization: Bearer \${RUNPOD_API_KEY}"
                        """, returnStdout: true).trim()

                        def sshPort = jsonPortMapping(podInfo, '22')
                        def publicIp = jsonField(podInfo, 'publicIp')

                        if (!sshPort || !publicIp) {
                            error("Nie znaleziono publicznego IP lub portu SSH dla poda ${params.POD_ID}. Upewnij się że pod ma otwarty port 22/tcp i jest uruchomiony.")
                        }

                        def branch = params.BRANCH
                        def ovhIp = params.OVH_IP
                        def githubToken = env.GITHUB_TOKEN
                        def setupLivePortrait = params.SETUP_LIVEPORTRAIT
                        echo "SSH: root@${publicIp}:${sshPort}"

                        writeFile file: 'remote_deploy.sh', text: """#!/bin/bash
set -e

# === Zatrzymaj działające procesy workera ===
echo "Stopping running worker processes..."
pkill -f "app.worker.sqs_worker" || true
sleep 2

# === Aktywacja conda ===
source /opt/conda/etc/profile.d/conda.sh

# === Repozytorium ===
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

# === Konfiguracja .env ===
ENV_FILE="rememoria/rememotion-python/.env"
if [ ! -f "\$ENV_FILE" ]; then
    echo "ERROR: \$ENV_FILE not found"
    exit 1
fi

sed -i "s|^TEST_MODE=.*|TEST_MODE=false|" "\$ENV_FILE"
sed -i "s|^PYTHONPATH=.*|PYTHONPATH=~/rememoria/rememotion-python|" "\$ENV_FILE"
sed -i "s|^\\(AWS_SQS_ENDPOINT=https\\?://\\)[^/:]*[^/]*|\\1${ovhIp}:4566|" "\$ENV_FILE"
sed -i "s|^\\(SQS_JOBS_URL=https\\?://\\)[^/:]*[^/]*|\\1${ovhIp}:4566|" "\$ENV_FILE"
sed -i "s|^\\(SQS_EVENTS_URL=https\\?://\\)[^/:]*[^/]*|\\1${ovhIp}:4566|" "\$ENV_FILE"
sed -i "s|^\\(AI_PHP_WEBHOOK_URL=https\\?://\\)[^/:]*[^/]*|\\1${ovhIp}:8080|" "\$ENV_FILE"

echo "=== Updated .env entries ==="
grep -E "^(TEST_MODE|PYTHONPATH|AWS_SQS_ENDPOINT|SQS_JOBS_URL|SQS_EVENTS_URL|AI_PHP_WEBHOOK_URL)=" "\$ENV_FILE"

# === Środowisko conda + instalacja ===
conda create -n rememotion python=3.10 -y 2>/dev/null || true
conda run -n rememotion pip install -U pip setuptools wheel
conda run -n rememotion pip install python-dotenv
conda run -n rememotion pip install rememoria/rememotion-python/.

# === Setup LivePortrait ===
${setupLivePortrait ? '''if [ -f ~/rememoria/docker/python-base/setup.sh ]; then
    bash ~/rememoria/docker/python-base/setup.sh
else
    echo "WARNING: ~/rememoria/docker/python-base/setup.sh not found, skipping"
fi''' : 'echo "Skipping LivePortrait setup (SETUP_LIVEPORTRAIT=false)"'}

# === Uruchomienie workera w tle ===
echo "Starting sqs_worker..."
cd ~/rememoria/rememotion-python
/opt/conda/envs/rememotion/bin/pip install .
nohup /opt/conda/envs/rememotion/bin/python -m app.worker.sqs_worker > /root/worker.log 2>&1 &
disown
echo "Worker PID: \$!"
echo "Logs: tail -f /root/worker.log"
"""

                        sh """
                            SSH_KEY=/var/jenkins_home/.ssh/id_ed25519
                            ssh -o StrictHostKeyChecking=no -o BatchMode=yes \
                                -o ServerAliveInterval=30 -o ServerAliveCountMax=10 \
                                -p ${sshPort} -i \${SSH_KEY} root@${publicIp} \
                                'bash -s' < remote_deploy.sh
                        """
                    }
                }
            }
        }
    }
    post {
        always {
            sh 'rm -f remote_deploy.sh'
        }
    }
}
