pipeline {
    agent any
    parameters {
        // RunPod
        string(name: 'POD_ID', defaultValue: '', description: '[WYMAGANE] ID poda RunPod do usunięcia')
        // OVH
        string(name: 'INSTANCE_NAME', defaultValue: 'rememotion-instance', description: 'Nazwa instancji OVH do usunięcia')
        string(name: 'FLAVOR',        defaultValue: 'd2-4',               description: 'Typ instancji OVH')
        string(name: 'IMAGE_NAME',    defaultValue: 'Ubuntu 24.04',       description: 'Obraz systemu OVH')
        string(name: 'REGION',        defaultValue: 'WAW1',               description: 'Region OVH')
        string(name: 'KEYPAIR_NAME',  defaultValue: 'rememotion-key',     description: 'Nazwa klucza SSH w OVH')
    }
    stages {
        stage('Validate parameters') {
            steps {
                script {
                    if (!params.POD_ID?.trim()) {
                        error('Parametr POD_ID jest wymagany!')
                    }
                    echo "Pod ID: ${params.POD_ID}"
                    echo "OVH Instance: ${params.INSTANCE_NAME} (${params.REGION})"
                }
            }
        }
        stage('Destroy Infrastructure') {
            failFast true
            parallel {
                stage('Remove RunPod Pod') {
                    steps {
                        build(
                            job: 'runpod-remove-pod',
                            parameters: [
                                string(name: 'POD_ID', value: params.POD_ID)
                            ],
                            propagate: true,
                            wait: true
                        )
                    }
                }
                stage('Destroy OVH Instance') {
                    steps {
                        build(
                            job: 'ovh-destroy-instance',
                            parameters: [
                                string(name: 'INSTANCE_NAME', value: params.INSTANCE_NAME),
                                string(name: 'FLAVOR',        value: params.FLAVOR),
                                string(name: 'IMAGE_NAME',    value: params.IMAGE_NAME),
                                string(name: 'REGION',        value: params.REGION),
                                string(name: 'KEYPAIR_NAME',  value: params.KEYPAIR_NAME)
                            ],
                            propagate: true,
                            wait: true
                        )
                    }
                }
            }
        }
    }
    post {
        success {
            echo """
=== INFRASTRUKTURA USUNIĘTA ===
RunPod Pod ID   : ${params.POD_ID}
OVH Instance    : ${params.INSTANCE_NAME} (${params.REGION})
"""
        }
    }
}
