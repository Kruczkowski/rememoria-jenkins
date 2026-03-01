pipeline {
    agent any
    parameters {
        string(name: 'INSTANCE_NAME', defaultValue: 'rememotion-instance', description: 'Nazwa instancji do usunięcia')
        string(name: 'FLAVOR', defaultValue: 'd2-4', description: 'Typ instancji OVH')
        string(name: 'IMAGE_NAME', defaultValue: 'Ubuntu 24.04', description: 'Obraz systemu')
        string(name: 'REGION', defaultValue: 'WAW1', description: 'Region OVH')
        string(name: 'KEYPAIR_NAME', defaultValue: 'rememotion-key', description: 'Nazwa klucza SSH w OVH')
    }
    stages {
        stage('Terraform Init') {
            steps {
                withCredentials([
                    string(credentialsId: 'OVH_TENANT_ID', variable: 'OS_TENANT_ID'),
                    string(credentialsId: 'OVH_USERNAME', variable: 'OS_USERNAME'),
                    string(credentialsId: 'OVH_PASSWORD', variable: 'OS_PASSWORD')
                ]) {
                    sh '''
                        rm -rf ${WORKSPACE}/ovh-instance
                        cp -r /opt/terraform/ovh-instance ${WORKSPACE}/ovh-instance
                        cd ${WORKSPACE}/ovh-instance
                        /usr/local/bin/terraform init
                    '''
                }
            }
        }
        stage('Terraform Import') {
            steps {
                withCredentials([
                    string(credentialsId: 'OVH_TENANT_ID', variable: 'OS_TENANT_ID'),
                    string(credentialsId: 'OVH_USERNAME', variable: 'OS_USERNAME'),
                    string(credentialsId: 'OVH_PASSWORD', variable: 'OS_PASSWORD')
                ]) {
                    script {
                        // Zapisz payload auth do pliku - unikamy interpolacji sekretów w Groovy
                        sh '''
                            cat > /tmp/os_auth_payload.json << 'JSONEOF'
{
  "auth": {
    "identity": {
      "methods": ["password"],
      "password": {
        "user": {
          "name": "PLACEHOLDER_USERNAME",
          "domain": {"id": "default"},
          "password": "PLACEHOLDER_PASSWORD"
        }
      }
    },
    "scope": {
      "project": {"id": "PLACEHOLDER_TENANT"}
    }
  }
}
JSONEOF
                            sed -i "s/PLACEHOLDER_USERNAME/${OS_USERNAME}/" /tmp/os_auth_payload.json
                            sed -i "s/PLACEHOLDER_PASSWORD/${OS_PASSWORD}/" /tmp/os_auth_payload.json
                            sed -i "s/PLACEHOLDER_TENANT/${OS_TENANT_ID}/" /tmp/os_auth_payload.json
                        '''

                        // Pobierz token
                        sh '''
                            curl -s -X POST https://auth.cloud.ovh.net/v3/auth/tokens \
                              -H "Content-Type: application/json" \
                              -d @/tmp/os_auth_payload.json \
                              -D /tmp/os_auth_headers.txt \
                              -o /tmp/os_auth_body.json
                            echo "--- Auth headers ---"
                            cat /tmp/os_auth_headers.txt
                        '''

                        def token = sh(script: "grep -i '^x-subject-token:' /tmp/os_auth_headers.txt | awk '{print \$2}' | tr -d '\\r\\n'", returnStdout: true).trim()
                        if (!token) {
                            sh 'cat /tmp/os_auth_body.json || true'
                            error("Nie udało się uzyskać tokenu OpenStack. Sprawdź credentials OVH.")
                        }
                        echo "Token uzyskany pomyślnie."

                        // Pobierz ID instancji po nazwie
                        def region = params.REGION.toLowerCase()
                        def instanceName = params.INSTANCE_NAME

                        // Token do pliku - nie trafia do env Jenkins
                        sh "printf '%s' '${token}' > /tmp/os_token.txt"

                        sh """
                            curl -s "https://compute.${region}.cloud.ovh.net/v2.1/\${OS_TENANT_ID}/servers?name=${instanceName}" \
                              -H "X-Auth-Token: \$(cat /tmp/os_token.txt)" \
                              -o /tmp/os_servers.json
                            echo "--- Servers response ---"
                            cat /tmp/os_servers.json
                        """

                        def instanceId = sh(script: """
                            python3 -c "import json; servers=json.load(open('/tmp/os_servers.json')).get('servers',[]); print(next((s['id'] for s in servers if s['name']=='${instanceName}'),''))"
                        """, returnStdout: true).trim()

                        if (!instanceId) {
                            error("Nie znaleziono instancji o nazwie '${instanceName}' w regionie ${params.REGION}")
                        }
                        env.INSTANCE_ID = instanceId
                        echo "Instance ID: ${instanceId}"

                        sh """
                            cd \${WORKSPACE}/ovh-instance
                            PUBLIC_KEY=\$(cat /var/jenkins_home/.ssh/id_ed25519.pub)
                            /usr/local/bin/terraform import \
                              -var "tenant_id=\${OS_TENANT_ID}" \
                              -var "user_name=\${OS_USERNAME}" \
                              -var "password=\${OS_PASSWORD}" \
                              -var "region=${params.REGION}" \
                              -var "keypair_name=${params.KEYPAIR_NAME}" \
                              -var "public_key=\${PUBLIC_KEY}" \
                              -var "instance_name=${params.INSTANCE_NAME}" \
                              openstack_compute_keypair_v2.keypair ${params.KEYPAIR_NAME} 2>/dev/null || true

                            /usr/local/bin/terraform import \
                              -var "tenant_id=\${OS_TENANT_ID}" \
                              -var "user_name=\${OS_USERNAME}" \
                              -var "password=\${OS_PASSWORD}" \
                              -var "region=${params.REGION}" \
                              -var "keypair_name=${params.KEYPAIR_NAME}" \
                              -var "public_key=\${PUBLIC_KEY}" \
                              -var "instance_name=${params.INSTANCE_NAME}" \
                              openstack_compute_instance_v2.instance ${env.INSTANCE_ID}
                        """
                    }
                }
            }
        }
        stage('Terraform Destroy') {
            steps {
                withCredentials([
                    string(credentialsId: 'OVH_TENANT_ID', variable: 'OS_TENANT_ID'),
                    string(credentialsId: 'OVH_USERNAME', variable: 'OS_USERNAME'),
                    string(credentialsId: 'OVH_PASSWORD', variable: 'OS_PASSWORD')
                ]) {
                    sh '''
                        cd ${WORKSPACE}/ovh-instance
                        PUBLIC_KEY=$(cat /var/jenkins_home/.ssh/id_ed25519.pub)
                        /usr/local/bin/terraform destroy -auto-approve \
                          -var "tenant_id=${OS_TENANT_ID}" \
                          -var "user_name=${OS_USERNAME}" \
                          -var "password=${OS_PASSWORD}" \
                          -var "region=${REGION}" \
                          -var "flavor=${FLAVOR}" \
                          -var "image_name=${IMAGE_NAME}" \
                          -var "keypair_name=${KEYPAIR_NAME}" \
                          -var "public_key=${PUBLIC_KEY}" \
                          -var "instance_name=${INSTANCE_NAME}" \
                          -target=openstack_compute_instance_v2.instance
                    '''
                }
            }
        }
    }
    post {
        success {
            echo "=== Instancja '${params.INSTANCE_NAME}' została usunięta ==="
        }
        always {
            sh 'rm -rf ${WORKSPACE}/ovh-instance /tmp/os_auth_payload.json /tmp/os_auth_headers.txt /tmp/os_auth_body.json /tmp/os_token.txt /tmp/os_servers.json || true'
        }
    }
}
