wget https://archive.apache.org/dist/kafka/2.2.1/kafka_2.12-2.2.1.tgz
tar -xzf kafka_2.12-2.2.1.tgz
sudo yum install jq -y
CLUSTER_ARN="${CLUSTER_ARN}"
PRIVATE_CA_ARN="${PRIVATE_CA_ARN}"
REGION_NAME="${AWS_REGION}"
TOPIC="AWSKafkaTutorialTopic"
ZOOKEEPER_STRING=$(aws kafka describe-cluster --region $REGION_NAME --cluster-arn $CLUSTER_ARN | jq -r ".ClusterInfo.ZookeeperConnectString")
echo $ZOOKEEPER_STRING
cd ~/environment/kafka_2.12-2.2.1
bin/kafka-topics.sh --create --zookeeper $ZOOKEEPER_STRING --replication-factor 2 --partitions 1 --topic $TOPIC
mkdir client && cd client
cp /usr/lib/jvm/java-11-amazon-corretto.x86_64/lib/security/cacerts kafka.client.truststore.jks
ALIAS="keyAlias"
PASSWORD="${PASSWORD}"
keytool -genkey -keystore kafka.client.keystore.jks -validity 300 -storepass $PASSWORD -keypass $PASSWORD -dname "CN=Distinguished-Name" -alias $ALIAS -storetype pkcs12
keytool -keystore kafka.client.keystore.jks -certreq -file client-cert-sign-request -alias $ALIAS -storepass $PASSWORD -keypass $PASSWORD
sed -i 's/NEW //' client-cert-sign-request
CERTIFICATE_ARN=$(aws acm-pca issue-certificate --certificate-authority-arn $PRIVATE_CA_ARN --csr fileb://client-cert-sign-request --signing-algorithm "SHA256WITHRSA" --validity Value=300,Type="DAYS" --region $REGION_NAME | jq -r ".CertificateArn")
aws acm-pca get-certificate --certificate-authority-arn $PRIVATE_CA_ARN --certificate-arn $CERTIFICATE_ARN --region $REGION_NAME | jq -r '"\(.CertificateChain)\n\(.Certificate)"' > signed-certificate-from-acm
keytool -keystore kafka.client.keystore.jks -import -file signed-certificate-from-acm -alias $ALIAS -storepass $PASSWORD -keypass $PASSWORD
# Prompt yes
aws secretsmanager create-secret --name Kafka_Keystore --secret-binary fileb://kafka.client.keystore.jks --region $REGION_NAME
cd ~/environment/kafka_2.12-2.2.1/client
sudo nano client.properties
# Paste
#security.protocol=SSL
#ssl.truststore.location=client/kafka.client.truststore.jks
#ssl.keystore.location=client/kafka.client.keystore.jks
#ssl.keystore.password=${PASSWORD}
#ssl.key.password=${PASSWORD}
cd ~/environment/kafka_2.12-2.2.1
BOOTSTRAP_SERVER=$(aws kafka get-bootstrap-brokers --region $REGION_NAME --cluster-arn $CLUSTER_ARN | jq -r ".BootstrapBrokerStringTls")
bin/kafka-console-producer.sh --broker-list $BOOTSTRAP_SERVER --topic $TOPIC --producer.config client/client.properties
cd ~/environment/kafka_2.12-2.2.1
BOOTSTRAP_SERVER=$(aws kafka get-bootstrap-brokers --region $REGION_NAME --cluster-arn $CLUSTER_ARN | jq -r ".BootstrapBrokerStringTls")
bin/kafka-console-consumer.sh --bootstrap-server $BOOTSTRAP_SERVER --topic $TOPIC --consumer.config client/client.properties --from-beginning