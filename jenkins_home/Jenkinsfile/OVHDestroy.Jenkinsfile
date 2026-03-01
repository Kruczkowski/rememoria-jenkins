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
                        // Pobierz token OpenStack
                        def authResponse = sh(script: """
                            curl -s -X POST https://auth.cloud.ovh.net/v3/auth/tokens \\
                              -H 'Content-Type: application/json' \\
                              -d '{
                                "auth": {
                                  "identity": {
                                    "methods": ["password"],
                                    "password": {
                                      "user": {
                                        "name": "${OS_USERNAME}",
                                        "domain": {"id": "default"},
                                        "password": "${OS_PASSWORD}"
                                      }
                                    }
                                  },
                                  "scope": {
                                    "project": {"id": "${OS_TENANT_ID}"}
                                  }
                                }
                              }' -D - -o /tmp/os_auth_body.json
                        """, returnStdout: true).trim()

                        def token = sh(script: "grep -i '^x-subject-token:' /tmp/os_auth_body.json | awk '{print \$2}' | tr -d '\\r'", returnStdout: true).trim()
                        if (!token) {
                            error("Nie udało się uzyskać tokenu OpenStack. Sprawdź credentials OVH.")
                        }
                        echo "Token uzyskany pomyślnie."

                        // Pobierz ID instancji po nazwie
                        def serversJson = sh(script: """
                            curl -s "https://compute.${params.REGION.toLowerCase()}.cloud.ovh.net/v2.1/${OS_TENANT_ID}/servers?name=${params.INSTANCE_NAME}" \\
                              -H "X-Auth-Token: ${token}"
                        """, returnStdout: true).trim()

                        echo "Servers response: ${serversJson}"

                        def instanceId = sh(script: """
                            echo '${serversJson}' | grep -o '"id": *"[^"]*"' | head -1 | grep -o '"[^"]*"\$' | tr -d '"'
                        """, returnStdout: true).trim()

                        if (!instanceId) {
                            error("Nie znaleziono instancji o nazwie '${params.INSTANCE_NAME}' w regionie ${params.REGION}")
                        }
                        env.INSTANCE_ID = instanceId
                        echo "Instance ID: ${instanceId}"

                        sh """
                            cd \${WORKSPACE}/ovh-instance
                            PUBLIC_KEY=\$(cat /var/jenkins_home/.ssh/id_ed25519.pub)
                            /usr/local/bin/terraform import \
                              -var "tenant_id=${OS_TENANT_ID}" \
                              -var "user_name=${OS_USERNAME}" \
                              -var "password=${OS_PASSWORD}" \
                              -var "region=${params.REGION}" \
                              -var "keypair_name=${params.KEYPAIR_NAME}" \
                              -var "public_key=\${PUBLIC_KEY}" \
                              -var "instance_name=${params.INSTANCE_NAME}" \
                              openstack_compute_keypair_v2.keypair ${params.KEYPAIR_NAME} 2>/dev/null || true

                            /usr/local/bin/terraform import \
                              -var "tenant_id=${OS_TENANT_ID}" \
                              -var "user_name=${OS_USERNAME}" \
                              -var "password=${OS_PASSWORD}" \
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
            sh 'rm -rf ${WORKSPACE}/ovh-instance || true'
        }
    }
}
