pipeline {
    agent any

    environment {
        REGISTRY = "cr.yandex/<registry-id>"
        APP_NAME = "nginx-static-app"
    }

    stages {
        stage('Checkout') {
            steps {
                git url: 'https://github.com/SeNike/nginx-static-app.git', branch: 'main'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("${REGISTRY}/${APP_NAME}:${env.GIT_COMMIT}")
                }
            }
        }

        stage('Push to YCR') {
            steps {
                script {
                    docker.withRegistry('https://cr.yandex', 'ycr-credentials') {
                        docker.image("${REGISTRY}/${APP_NAME}:${env.GIT_COMMIT}").push()
                    }
                }
            }
        }

        stage('Tagged Release') {
            when {
                buildingTag()
            }
            steps {
                script {
                    // Пуш тегированного образа
                    docker.image("${REGISTRY}/${APP_NAME}:${env.GIT_COMMIT}").push("${env.TAG_NAME}")
                    
                    // Деплой в Kubernetes
                    sh """
                        kubectl set image deployment/nginx-deployment \
                        nginx=${REGISTRY}/${APP_NAME}:${env.TAG_NAME} --record
                    """
                }
            }
        }
    }
}