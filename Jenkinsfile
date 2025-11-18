pipeline {
    agent any

    environment {
        SONAR_TOKEN = credentials('sonar-token')
        NEXUS_CRED = credentials('NEXUS-CRED')
        DOCKER_HUB = credentials('dockerhub-user')
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
                    echo "Node version:"
                    node -v

                    echo "NPM version:"
                    npm -v

                    echo Installing Node dependencies...
                    npm install --no-audit --no-fund
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('My-Sonar') {
                    sh '''
                        /opt/sonar-scanner/bin/sonar-scanner \
                          -Dsonar.projectKey=nodeapp \
                          -Dsonar.sources=. \
                          -Dsonar.host.url=http://3.89.29.36:9000 \
                          -Dsonar.login=$SONAR_TOKEN
                    '''
                }
            }
        }

        stage('Upload to Nexus') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'NEXUS-CRED', usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                    sh '''
                        echo "Creating TAR..."
                        tar --ignore-failed-read --warning=no-file-changed -czf nodeapp.tar.gz *

                        echo "Uploading to Nexus..."
                        curl -v -u $NEXUS_USER:$NEXUS_PASS \
                            --upload-file nodeapp.tar.gz \
                            http://3.89.29.36:8081/repository/nodejs/nodeapp.tar.gz
                    '''
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build -t kishan/nodeapp:latest .
                '''
            }
        }

        stage('Push Docker Image') {
            steps {
                sh '''
                    echo $DOCKER_HUB_PSW | docker login -u $DOCKER_HUB_USR --password-stdin
                    docker push kishan/nodeapp:latest
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
