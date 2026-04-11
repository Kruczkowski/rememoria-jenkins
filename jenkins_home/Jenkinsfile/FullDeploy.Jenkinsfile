// ============================================================
// FullDeploy.Jenkinsfile
// Orkiestrator - kompletny deployment ReMemotion
//
// Wymagane nazwy jobów w Jenkins:
//   - ovh-create-instance      (OVHInstance.Jenkinsfile)
//   - runpod-create-pod-volume (PodWithVolume.Jenkinsfile)
//   - runpod-deploy            (RunPodDeploy.Jenkinsfile)
// ============================================================

@NonCPS
def parseInstanceIp(String description) {
    def m = description =~ /INSTANCE_IP:([^\s]+)/
    return m ? m[0][1] : ''
}

@NonCPS
def parsePodId(String description) {
    def m = description =~ /Pod ID:\s*([^\s|]+)/
    return m ? m[0][1] : ''
}

pipeline {
    agent any

    parameters {
        // --- Wymagane ---
        string(name: 'NETWORK_VOLUME_ID',
               defaultValue: '',
               description: '[WYMAGANE] ID Network Storage w RunPod')

        // --- Wspólne ---
        string(name: 'BRANCH',
               defaultValue: 'main',
               description: 'Branch repozytorium do wdrożenia')

        // --- RunPod ---
        string(name: 'GPU_TYPE',
               defaultValue: 'NVIDIA RTX 2000 Ada Generation',
               description: 'Typ GPU w RunPod')
        string(name: 'DISK_SIZE',
               defaultValue: '10',
               description: 'Rozmiar dysku kontenera RunPod (GB)')
        string(name: 'IMAGE',
               defaultValue: 'ghcr.io/kruczkowski/rememotion-python-base:latest',
               description: 'Obraz Docker dla poda RunPod')

        // --- OVH ---
        string(name: 'OVH_INSTANCE_NAME',
               defaultValue: 'rememotion-instance',
               description: 'Nazwa instancji OVH')
        string(name: 'OVH_FLAVOR',
               defaultValue: 'd2-4',
               description: 'Typ instancji OVH (np. d2-4)')
        string(name: 'OVH_IMAGE_NAME',
               defaultValue: 'Ubuntu 24.04',
               description: 'Obraz systemu OVH')
        string(name: 'OVH_REGION',
               defaultValue: 'WAW1',
               description: 'Region OVH')
        string(name: 'OVH_KEYPAIR_NAME',
               defaultValue: 'rememotion-key',
               description: 'Nazwa klucza SSH w OVH')
    }

    stages {

        stage('Validate parameters') {
            steps {
                script {
                    if (params.NETWORK_VOLUME_ID?.trim()) {
                        echo "Network Volume ID: ${params.NETWORK_VOLUME_ID}"
                    } else {
                        echo 'NETWORK_VOLUME_ID nie podano - zostanie użyty Pod bez Network Volume'
                    }
                    echo "Branch: ${params.BRANCH}"
                }
            }
        }

        // Stage 1 - tworzenie instancji OVH
        stage('Create OVH Instance') {
            steps {
                script {
                    def ovhBuild = build(
                        job: 'ovh-create-instance',
                        parameters: [
                            string(name: 'INSTANCE_NAME', value: params.OVH_INSTANCE_NAME),
                            string(name: 'FLAVOR',        value: params.OVH_FLAVOR),
                            string(name: 'IMAGE_NAME',    value: params.OVH_IMAGE_NAME),
                            string(name: 'REGION',        value: params.OVH_REGION),
                            string(name: 'KEYPAIR_NAME',  value: params.OVH_KEYPAIR_NAME)
                        ],
                        propagate: true,
                        wait: true
                    )
                    def instanceIp = parseInstanceIp(ovhBuild.description ?: '')
                    if (!instanceIp) {
                        error("Nie udało się odczytać IP instancji OVH z opisu builda. Opis: ${ovhBuild.description}")
                    }
                    env.INSTANCE_IP = instanceIp
                    echo "OVH Instance IP: ${env.INSTANCE_IP}"
                }
            }
        }

        // Stage 2 - deploy na OVH
        stage('Deploy to OVH') {
            steps {
                script {
                    echo "Deploying application to OVH instance ${env.INSTANCE_IP}..."
                    build(
                        job: 'ovh-deploy-application',
                        parameters: [
                            string(name: 'VM_IP',   value: env.INSTANCE_IP),
                            string(name: 'VM_USER', value: 'ubuntu'),
                            string(name: 'BRANCH',  value: params.BRANCH)
                        ],
                        propagate: true,
                        wait: true
                    )
                }
            }
        }

        // Stage 3 - tworzenie poda RunPod
        stage('Create RunPod Pod') {
            steps {
                script {
                    def podBuild
                    if (params.NETWORK_VOLUME_ID?.trim()) {
                        echo "Tworzenie poda z Network Volume: ${params.NETWORK_VOLUME_ID}"
                        podBuild = build(
                            job: 'runpod-create-pod-with-volume',
                            parameters: [
                                string(name: 'GPU_TYPE',          value: params.GPU_TYPE),
                                string(name: 'DISK_SIZE',         value: params.DISK_SIZE),
                                string(name: 'NETWORK_VOLUME_ID', value: params.NETWORK_VOLUME_ID),
                                string(name: 'IMAGE',             value: params.IMAGE)
                            ],
                            propagate: true,
                            wait: true
                        )
                    } else {
                        echo 'Tworzenie poda bez Network Volume'
                        podBuild = build(
                            job: 'runpod-create-pod',
                            parameters: [
                                string(name: 'GPU_TYPE',  value: params.GPU_TYPE),
                                string(name: 'DISK_SIZE', value: params.DISK_SIZE),
                                string(name: 'IMAGE',     value: params.IMAGE)
                            ],
                            propagate: true,
                            wait: true
                        )
                    }
                    def podId = parsePodId(podBuild.description ?: '')
                    if (!podId) {
                        error("Nie udało się odczytać Pod ID z opisu builda. Opis: ${podBuild.description}")
                    }
                    env.POD_ID = podId
                    echo "RunPod Pod ID: ${env.POD_ID}"
                }
            }
        }

        // Stage 4 - deploy w RunPod
        stage('Deploy to RunPod') {
            steps {
                script {
                    echo "Deploying to RunPod pod ${env.POD_ID} with OVH IP ${env.INSTANCE_IP}..."
                    build(
                        job: 'runpod-deploy-application',
                        parameters: [
                            string(name: 'POD_ID',  value: env.POD_ID),
                            string(name: 'OVH_IP',  value: env.INSTANCE_IP),
                            string(name: 'BRANCH',  value: params.BRANCH)
                        ],
                        propagate: true,
                        wait: true
                    )
                }
            }
        }

    }

    post {
        success {
            script {
                currentBuild.description = "OVH: ${env.INSTANCE_IP} | Pod: ${env.POD_ID}"
                echo """
=== DEPLOYMENT ZAKOŃCZONY SUKCESEM ===
OVH Instance IP : ${env.INSTANCE_IP}
RunPod Pod ID   : ${env.POD_ID}
Branch          : ${params.BRANCH}
"""
            }
        }
        failure {
            echo "=== DEPLOYMENT ZAKOŃCZONY BŁĘDEM ==="
        }
    }
}
