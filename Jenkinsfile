pipeline {
    agent any

    tools {
        nodejs 'NodeJS-20'
    }

    environment {
        DOCKER_IMAGE = "kishangollamudi/nodeapp"
        VERSION = "${env.BUILD_NUMBER}"
        NEXUS_REPO = "nodejs"
        NEXUS_URL  = "http://54.85.207.105:8081/repository"
    }

    stages {

        stage('Checkout') {
            steps {
                echo "Checking out code..."
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                echo "Running npm install..."
                sh "npm install"
            }
        }

        stage('Run Tests') {
            steps {
                echo "Skipping tests..."
                sh 'echo "Tests skipped"'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                echo "Running SonarQube analysis..."
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                    withSonarQubeEnv('My-Sonar') {
                        sh """
                            ${tool 'SonarScanner'}/bin/sonar-scanner \
                              -Dsonar.projectKey=nodeapp \
                              -Dsonar.sources=. \
                              -Dsonar.login=$SONAR_TOKEN
                        """
                    }
                }
            }
        }

        stage('Package Artifact') {
            steps {
                echo "Creating ZIP..."
                sh "apt-get update && apt-get install -y zip"
                sh "zip -r nodeapp-${VERSION}.zip ."
            }
        }

        stage('Upload to Nexus') {
            steps {
                echo "Uploading to Nexus RAW repository..."
                withCredentials([usernamePassword(
                    credentialsId: 'nexus',
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {
                    sh """
                        curl -v -u $NEXUS_USER:$NEXUS_PASS \
                        --upload-file nodeapp-${VERSION}.zip \
                        ${NEXUS_URL}/nodejs/nodeapp-${VERSION}.zip
                    """
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("${DOCKER_IMAGE}:${VERSION}")
                }
            }
        }

        stage('Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-user',
                    usernameVariable: 'DH_USER',
                    passwordVariable: 'DH_PASS'
                )]) {
                    sh """
                        echo $DH_PASS | docker login -u $DH_USER --password-stdin
                        docker push ${DOCKER_IMAGE}:${VERSION}
                        docker tag ${DOCKER_IMAGE}:${VERSION} ${DOCKER_IMAGE}:latest
                        docker push ${DOCKER_IMAGE}:latest
                    """
                }
            }
        }
    }

    post {
        always {
            echo "Cleaning Workspace..."
            cleanWs()
        }
    }
}
