pipeline {
    agent any
    parameters {
        string(name: 'POD_ID', defaultValue: '', description: 'ID poda do usunięcia')
    }
    stages {
        stage('Terminate RunPod Pod') {
            steps {
                withCredentials([string(credentialsId: 'RUNPOD_API_KEY', variable: 'RUNPOD_API_KEY')]) {
                    sh '''
                        mkdir -p /var/jenkins_home/.runpod
                        runpodctl config --apiKey ${RUNPOD_API_KEY}
                        runpodctl remove pod ${POD_ID}
                    '''
                }
            }
        }
    }
}
