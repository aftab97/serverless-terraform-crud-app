# SERVERLESS-TERRAFORM-CRUD-APP

AWS Lambda functions and API gateway are often used to create serverless
applications.

This project demonstrates a serverless approach to creating a CRUD app which gets data from a Dynamo Database
using Lambda Functions behind a API Gateway.

For a better understanding of the components involved see the below diagram

## Diagram of the Serverless CRUD App
![alt text](https://github.com/aftab97/SERVERLESS-TERRAFORM-CRUD-APP/blob/main/diagram.png?raw=true)

## Prequisites:

Node version: v18.19.0 | Terraform: v1.8.1 | NPM: 10.2.3 | AWS CLI V2: 2.15.40

## To install & run:

CD into students folder and ``run npm install``

CD back into the root directory and run ``terraform init``

Run ``terraform apply`` to deploy to AWS
Run ``terraform destroy`` to remove from AWS