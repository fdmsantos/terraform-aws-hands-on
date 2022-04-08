# Deliver data at scale to amazon MSK with IOT Core

[Link](https://aws.amazon.com/getting-started/hands-on/deliver-data-at-scale-to-amazon-msk-with-iot-core/?trk=gs_card)

In this tutorial, you learn how to stream IoT data on an Amazon Managed Streaming for Apache Kafka (Amazon MSK) cluster using AWS IoT Core rules.

Amazon MSK is a fully managed service that makes it easy for you to build and run applications that use Apache Kafka to process streaming data. Apache Kafka is an open-source platform for building real-time streaming data pipelines and applications. With Amazon MSK, you can use native Apache Kafka APIs to populate data lakes, stream changes to and from databases, and power machine learning and analytics applications.

AWS IoT Core lets you connect IoT devices to the AWS cloud without the need to provision or manage servers. AWS IoT Core can support billions of devices and trillions of messages, and can process and route those messages to AWS endpoints and to other devices reliably and securely.
In this tutorial you learn how to:

* Set up Private Certificate Authority (CA) with AWS Certificate Manager
* Set up an Apache Kafka cluster with Amazon MSK
* Configure Kafka authentication and test the stream using AWS Cloud9
* Prepare Java KeyStore and configure an AWS Secrets Manager secret
* Configure an AWS IoT Core rule to deliver messages to the Kafka cluster
* Set up error logging for AWS IoT Core rules and service

## Pre Requisites

* Terraform
* Create Cloud9 Environment

## Resources Created

* AWS MSK
* IAM Roles
* Cloud9
* IOT Core Rule
* Private CA and Certificates
* Secrets