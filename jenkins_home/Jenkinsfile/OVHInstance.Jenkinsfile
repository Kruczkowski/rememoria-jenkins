pipeline {
    agent any
    parameters {
        string(name: 'INSTANCE_NAME', defaultValue: 'rememotion-instance', description: 'Nazwa instancji')
        string(name: 'FLAVOR', defaultValue: 'd2-4', description: 'Typ instancji OVH (np. d2-4)')
        string(name: 'IMAGE_NAME', defaultValue: 'Ubuntu 24.04', description: 'Obraz systemu (Ubuntu LTS)')
        string(name: 'REGION', defaultValue: 'WAW1', description: 'Region OVH (np. WAW1 - Warszawa)')
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
        stage('Terraform Apply') {
            steps {
                withCredentials([
                    string(credentialsId: 'OVH_TENANT_ID', variable: 'OS_TENANT_ID'),
                    string(credentialsId: 'OVH_USERNAME', variable: 'OS_USERNAME'),
                    string(credentialsId: 'OVH_PASSWORD', variable: 'OS_PASSWORD')
                ]) {
                    sh '''
                        cd ${WORKSPACE}/ovh-instance
                        /usr/local/bin/terraform apply -auto-approve \
                          -var "tenant_id=${OS_TENANT_ID}" \
                          -var "user_name=${OS_USERNAME}" \
                          -var "password=${OS_PASSWORD}" \
                          -var "region=${REGION}" \
                          -var "flavor=${FLAVOR}" \
                          -var "image_name=${IMAGE_NAME}" \
                          -var "keypair_name=${KEYPAIR_NAME}" \
                          -var "instance_name=${INSTANCE_NAME}"
                    '''
                }
            }
        }
        stage('Show Outputs') {
            steps {
                sh '''
                    cd ${WORKSPACE}/ovh-instance
                    /usr/local/bin/terraform output
                '''
                script {
                    def ip = sh(
                        script: "cd ${WORKSPACE}/ovh-instance && /usr/local/bin/terraform output -raw instance_ip",
                        returnStdout: true
                    ).trim()
                    env.INSTANCE_IP = ip
                    echo "Instance IP: ${ip}"
                    currentBuild.description = "INSTANCE_IP:${ip}"
                }
            }
        }
        stage('Deploy Application') {
            steps {
                build job: 'ovh-deploy-application',
                      parameters: [
                          string(name: 'VM_IP', value: env.INSTANCE_IP),
                          string(name: 'VM_USER', value: 'ubuntu')
                      ]
            }
        }
    }
}
