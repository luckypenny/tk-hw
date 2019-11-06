#!/bin/bash
command=$1

# 인프라 생성
if [ $command == "create" ]; then
  terraform apply -auto-approve config 
  echo "creation complete"
# terraform으로 구성된 인프라를 제거합니다.
elif [ $command == "destroy" ]; then
  terraform destroy -auto-approve config
  echo "destroy complete"
# index.html 파일을 tk-web 태그로 구분된 인스턴스에 배포합니다.(파일 복사)
elif [ $command == 'deploy' ]; then
  echo "deploy"
  ssh-add -K ssh_key/id_tk_web
  bastion_ip=$(aws ec2 describe-instances --region=ap-northeast-2 --filters "Name=tag:Name,Values=tk-bastion" --query "Reservations[].Instances[].PublicIpAddress" --output text)
  echo "bastion_ip : ${bastion_ip}"
  scp index.html ubuntu@${bastion_ip}:/home/ubuntu/index.html
  web_ips=$(aws ec2 describe-instances --region=ap-northeast-2 --filters "Name=tag:Name,Values=tk-web" --query "Reservations[].Instances[].PrivateIpAddress" --output text)
  for web_ip in $web_ips; do
    ssh -A ubuntu@${bastion_ip} "scp -o StrictHostKeyChecking=no index.html ubuntu@${web_ip}:/home/ubuntu/index.html"
    ssh -A ubuntu@${bastion_ip} "ssh ubuntu@${web_ip} 'sudo cp index.html /var/www/html/index.html'"
    echo 'web private ip '${web_ip}' 으로 배포 되었습니다.'
  done
else
  echo "./deploy.sh [create | destroy | deploy]"
fi