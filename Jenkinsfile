pipeline {
    agent any

    environment {
        VAULT_ADDR = "http://127.0.0.1:8200"
        VAULT_TOKEN = "education"
    }

    stages {
        stage('Get Credentials from Vault') {
            steps {
                script {
                    def access_key = sh(script: "docker run --network=host -e VAULT_ADDR='${VAULT_ADDR}' -e VAULT_TOKEN='${VAULT_TOKEN}' vault:1.13.3 sh -c \"vault kv get -field=value secret/access_key\"", returnStdout: true).trim()
                    def secret_key = sh(script: "docker run --network=host -e VAULT_ADDR='${VAULT_ADDR}' -e VAULT_TOKEN='${VAULT_TOKEN}' vault:1.13.3 sh -c \"vault kv get -field=value secret/secret_key\"", returnStdout: true).trim()

                    env.ACCESS_KEY = access_key
                    env.SECRET_KEY = secret_key
                }
            }
        }

        stage('Terraform Init') {
            steps {
                 sh """
                    export PATH="/var/lib/jenkins:$PATH"
                    terraform init -backend-config=\"access_key=${env.ACCESS_KEY}\" -backend-config=\"secret_key=${env.SECRET_KEY}\" > /dev/null
                    """

            }
        }
        stage('Terraform apply') {
            steps {
             sh """
                export PATH="/var/lib/jenkins:$PATH"
                terraform apply -auto-approve
                """  
            }
        }        
    }
}