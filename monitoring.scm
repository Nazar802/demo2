node {
    def remote = [:]
    remote.name = 'front'
    remote.host = '20.120.10.138'
    remote.user = 'azureuser'
    remote.allowAnyHosts = true
    
    withCredentials([file(credentialsId: 'keyssh', variable: 'vm16')]){
        remote.identityFile = vm16
        
        stage('Cleanup') {
            writeFile file: 'cleanup.sh', text:
            "rm -rf dockerfile\ndocker stop node_exporter || true && docker rm node_exporter || true\ndocker stop cadvisor || true && docker rm cadvisor || true\ndocker stop grafana || true && docker rm grafana || true\ndocker stop prometheus || true && docker rm prometheus || true"
            sshScript remote: remote, script: "cleanup.sh"
        }
        
        stage('Scm Checkout') {
            sshCommand remote: remote, command: 'git clone --branch monitoring https://github.com/Nazar802/dockerfile.git'
        }
        
        stage ('Docker-Compose Up') {
            writeFile file: 'start.sh', text: 
            "cd dockerfile\ndocker-compose up -d"
            sshScript remote: remote, script: "start.sh"
        }
        
        /*stage ('Dokcer Push') {
            writeFile file: 'push.sh', text:
            "cd dockerfile\ndocker login commonregistry646.azurecr.io -uCommonRegistry646 -p${CommonPass}\ndocker-compose push"
        }*/
    }
    
}
