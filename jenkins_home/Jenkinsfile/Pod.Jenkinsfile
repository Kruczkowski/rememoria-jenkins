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
        string(name: 'GPU_TYPE', defaultValue: 'NVIDIA RTX 2000 Ada Generation', description: 'Typ GPU (np. NVIDIA RTX 2000 Ada Generation)')
        string(name: 'DISK_SIZE', defaultValue: '10', description: 'Rozmiar dysku w GB')
        string(name: 'IMAGE', defaultValue: 'ghcr.io/kruczkowski/rememotion-python-base:latest', description: 'Obraz Docker')
    }
    stages {
        stage('Create RunPod Pod') {
            steps {
                withCredentials([
                    string(credentialsId: 'RUNPOD_API_KEY', variable: 'RUNPOD_API_KEY'),
                    string(credentialsId: 'RUNPOD_REGISTRY_AUTH_ID', variable: 'RUNPOD_REGISTRY_AUTH_ID')
                ]) {
                    script {
                        def registryAuthId = env.RUNPOD_REGISTRY_AUTH_ID
                        writeFile file: 'payload.json', text: groovy.json.JsonOutput.toJson([
                            cloudType               : 'SECURE',
                            computeType             : 'GPU',
                            gpuCount                : 1,
                            gpuTypeIds              : [params.GPU_TYPE],
                            gpuTypePriority         : 'availability',
                            imageName               : params.IMAGE,
                            name                    : 'rememotion-pod',
                            containerDiskInGb       : params.DISK_SIZE.toInteger(),
                            volumeInGb              : params.DISK_SIZE.toInteger(),
                            volumeMountPath         : '/workspace',
                            containerRegistryAuthId : registryAuthId ?: null,
                            ports                   : ['22/tcp'],
                            minRAMPerGPU            : 8,
                            vcpuCount               : 2,
                            supportPublicIp         : true
                        ])

                        def response = sh(script: '''
                            curl -s -X POST "https://rest.runpod.io/v1/pods" \
                              -H "Authorization: Bearer ${RUNPOD_API_KEY}" \
                              -H "Content-Type: application/json" \
                              -d @payload.json
                        ''', returnStdout: true).trim()

                        echo "RunPod API response: ${response}"

                        if (response.contains('"error"') || response.contains('"errors"')) {
                            error("RunPod API zwróciło błąd: ${response}")
                        }

                        env.POD_ID = jsonField(response, 'id')
                        echo "Pod ID: ${env.POD_ID}"
                    }
                }
            }
        }
        stage('Wait for Running') {
            steps {
                withCredentials([string(credentialsId: 'RUNPOD_API_KEY', variable: 'RUNPOD_API_KEY')]) {
                    script {
                        echo "Waiting for pod ${env.POD_ID} to reach RUNNING state..."
                        timeout(time: 15, unit: 'MINUTES') {
                            waitUntil(initialRecurrencePeriod: 10000) {
                                def podInfo = sh(script: """
                                    curl -s "https://rest.runpod.io/v1/pods/${env.POD_ID}" \
                                      -H "Authorization: Bearer \${RUNPOD_API_KEY}"
                                """, returnStdout: true).trim()
                                echo "RAW API response: ${podInfo}"
                                def desiredStatus = jsonField(podInfo, 'desiredStatus') ?: 'UNKNOWN'
                                def podIp = jsonField(podInfo, 'publicIp')
                                echo "Status: desired=${desiredStatus}, publicIp=${podIp}"
                                return desiredStatus == 'RUNNING' && podIp
                            }
                        }
                        echo "Container is RUNNING, waiting for SSH..."
                        def SSH_KEY = '/var/jenkins_home/.ssh/id_ed25519'
                        def podInfo2 = sh(script: """
                            curl -s "https://rest.runpod.io/v1/pods/${env.POD_ID}" \
                              -H "Authorization: Bearer \${RUNPOD_API_KEY}"
                        """, returnStdout: true).trim()
                        def publicIp = jsonField(podInfo2, 'publicIp')
                        def sshPort = jsonPortMapping(podInfo2, '22')
                        echo "SSH: root@${publicIp}:${sshPort}"
                        timeout(time: 10, unit: 'MINUTES') {
                            waitUntil(initialRecurrencePeriod: 10000) {
                                def sshResult = sh(script: """
                                    ssh -o StrictHostKeyChecking=no -o BatchMode=yes \
                                        -o ConnectTimeout=5 \\
                                        -o ServerAliveInterval=5 -o ServerAliveCountMax=3 \\
                                        -p ${sshPort} -i ${SSH_KEY} root@${publicIp} echo ok 2>/dev/null
                                """, returnStatus: true)
                                echo "SSH probe exit code: ${sshResult}"
                                return sshResult == 0
                            }
                        }
                        echo "=== Pod is RUNNING and SSH is accessible ==="
                        echo "Pod ID: ${env.POD_ID}"
                        echo "SSH: root@${publicIp} -p ${sshPort}"
                        currentBuild.description = "Pod ID: ${env.POD_ID} | SSH: root@${publicIp}:${sshPort}"
                    }
                }
            }
        }
    }
    post {
        always {
            sh 'rm -f payload.json'
        }
    }
}