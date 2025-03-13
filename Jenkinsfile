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
                    def token = sh(script: "docker run --network=host -e VAULT_ADDR='${VAULT_ADDR}' -e VAULT_TOKEN='${VAULT_TOKEN}' vault:1.13.3 sh -c \"vault kv get -field=value secret/token\"", returnStdout: true).trim()
                    def cloud_id = sh(script: "docker run --network=host -e VAULT_ADDR='${VAULT_ADDR}' -e VAULT_TOKEN='${VAULT_TOKEN}' vault:1.13.3 sh -c \"vault kv get -field=value secret/cloud_id\"", returnStdout: true).trim()       
                    def folder_id = sh(script: "docker run --network=host -e VAULT_ADDR='${VAULT_ADDR}' -e VAULT_TOKEN='${VAULT_TOKEN}' vault:1.13.3 sh -c \"vault kv get -field=value secret/folder_id\"", returnStdout: true).trim()
                    def service_account_id = sh(script: "docker run --network=host -e VAULT_ADDR='${VAULT_ADDR}' -e VAULT_TOKEN='${VAULT_TOKEN}' vault:1.13.3 sh -c \"vault kv get -field=value secret/service_account_id\"", returnStdout: true).trim()    
                    def registry_id = sh(script: "docker run --network=host -e VAULT_ADDR='${VAULT_ADDR}' -e VAULT_TOKEN='${VAULT_TOKEN}' vault:1.13.3 sh -c \"vault kv get -field=value secret/registry_id\"", returnStdout: true).trim()                              


                    env.ACCESS_KEY = access_key
                    env.SECRET_KEY = secret_key
                    env.TOKEN = token
                    env.CLOUD_ID = cloud_id
                    env.FOLDER_ID = folder_id
                    env.SERVICE_ACCOUNT_ID = service_account_id
                    env.REGISTRY_ID = registry_id
                }
            }
        }

        stage('Terraform Init') {
            steps {
                 sh """
                    export PATH="/var/lib/jenkins:$PATH"
                    cd main-infra/
                    terraform init -backend-config=\"access_key=${env.ACCESS_KEY}\" -backend-config=\"secret_key=${env.SECRET_KEY}\" > /dev/null
                    """

            }
        }
        stage('Terraform apply') {
            steps {
             sh """
                    export PATH="/var/lib/jenkins:$PATH"
                    cd main-infra/   
                    terraform apply \
                    -var="token=${env.TOKEN}" \
                    -var="cloud_id=${env.CLOUD_ID}" \
                    -var="folder_id=${env.FOLDER_ID}" \
                    -var="service_account_id=${env.SERVICE_ACCOUNT_ID}" \
                    -var="registry_id=${env.REGISTRY_ID}"
                    """  
            }
        }        
    }
}