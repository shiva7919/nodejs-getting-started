pipeline {
    agent any

    environment {
        SONAR_TOKEN = credentials('sonar-token')
        NEXUS_CRED  = credentials('nexus')
        DOCKER_HUB  = credentials('dockerhub-user')
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/KishanGollamudi/nodejs-getting-started.git'
            }
        }

        stage('Install Dependencies') {
            steps {
                sh '''
                    node -v
                    npm -v
                    
                    echo "Installing Node dependencies..."
                    npm install --no-audit --no-fund
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('My-Sonar') {
                    sh '''
                        sonar-scanner \
                        -Dsonar.projectKey=nodeapp \
                        -Dsonar.sources=. \
                        -Dsonar.host.url=http://54.85.207.105:9000 \
                        -Dsonar.login=$SONAR_TOKEN
                    '''
                }
            }
        }

        stage('Package Artifact') {
            steps {
                sh '''
                    zip -r artifact.zip . -x "node_modules/*"
                '''
            }
        }

        stage('Upload to Nexus') {
            steps {
                sh '''
                    curl -u $NEXUS_CRED_USR:$NEXUS_CRED_PSW \
                    --upload-file artifact.zip \
                    http://54.85.207.105:8081/repository/nodejs/artifact-${BUILD_NUMBER}.zip
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build \
                    -t kishangollamudi/nodeapp:${BUILD_NUMBER} .
                '''
            }
        }

        stage('Push Docker Image') {
            steps {
                sh '''
                    echo $DOCKER_HUB_PSW | docker login -u $DOCKER_HUB_USR --password-stdin
                    docker push kishangollamudi/nodeapp:${BUILD_NUMBER}
                '''
            }
        }
    }

    post {
        always {
            echo "Pipeline finished!"
        }
    }
}
