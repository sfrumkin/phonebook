This is a phonebook project deployed in aws via terraform.

I used aws-vault to configure permissions.  You must add MFA device to the profile for this to work.

aws-vault exec --duration=12h sfrumkin22

cd auth-cognito

docker-compose -f deploy/docker-compose.yml run --rm terraform init
docker-compose -f deploy/docker-compose.yml run --rm terraform plan
docker-compose -f deploy/docker-compose.yml run --rm terraform apply
docker-compose -f deploy/docker-compose.yml run --rm terraform destroy

Performance testing done via k6:

Url outputted by terraform should be used in k6 script

k6 run deploy\test\k6-load.js

