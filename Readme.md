# KEDA Sample for GCP PubSub

This is an example of using [KEDA](https://github.com/kedacore/keda) with GCP PubSub.

KEDA (Kubernetes-based Event Driven Autoscaling) allows you to auto scale your kubernetes pods based on external metrics derived from systems such as RabbitMQ, Azure Storage Queues, GCP PubSub, Azure ServiceBus, etc. It also lets your scale the number of pods to zero so that you're not consuming resources when there is no processing to be done.

# Prerequisites
You need a Kubernetes cluster with KEDA installed. The [KEDA git hub repository](https://github.com/kedacore/keda) explains how this can be done using Helm.

Additionally, you must be comfortable with the gcloud command line tool and should have setup a GCP account and project.

# Tutorial

We shall start by creating a service account in GCP. This service account will be used by KEDA to figure out how many messages are present in the PubSub subscription as well as by our sample program that will receive messages from the subscription. We will give the service account access to view Stackdriver metrics. The metric called "pubsub.googleapis.com/subscription/num_undelivered_messages" is updated by PubSub when new messages are added to the subscription.

```sh
SERVICE_ACCOUNT_NAME=gcppubsubtest
PROJECT_ID=$(gcloud config get-value project)
SERVICE_ACCOUNT_FULL_NAME=$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com

gcloud beta iam service-accounts create $SERVICE_ACCOUNT_NAME \
    --display-name "PubSub Sample"

gcloud iam service-accounts keys create $(pwd)/sa.json \
  --iam-account $SERVICE_ACCOUNT_FULL_NAME

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$SERVICE_ACCOUNT_FULL_NAME \
  --role roles/monitoring.viewer
```

Next we will create the topic and the subscription

```sh
SUBSCRIPTION_NAME=mysubscription
TOPIC_NAME=mytopic

# Create Topic
gcloud beta pubsub topics create $TOPIC_NAME

# Create Subscription
gcloud beta pubsub subscriptions create $SUBSCRIPTION_NAME \
  --topic $TOPIC_NAME

# We need to give the service account access to the subscriber to
# receive messages
gcloud beta pubsub subscriptions add-iam-policy-binding $SUBSCRIPTION_NAME \
  --member=serviceAccount:$SERVICE_ACCOUNT_FULL_NAME \
  --role=roles/pubsub.subscriber
```

Now we will create the namespace and deploy the application. We will create a secret containing the service account keys and the project ID and then use those as environment variables in the Deployment yaml

```sh
kubectl create ns keda-pubsub-test

kubectl create secret generic pubsub-secret \
  --from-file=GOOGLE_APPLICATION_CREDENTIALS_JSON=./sa.json \
  --from-literal=PROJECT_ID=$PROJECT_ID \
  -n keda-pubsub-test


kubectl apply -f manifests/
```

This is the YAML for the Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keda-pubsub-go
  namespace: keda-pubsub-test
spec:
  selector:
    matchLabels:
      service: keda-pubsub-go
  replicas: 1
  template:
    metadata:
      labels:
        service: keda-pubsub-go
    spec:
      containers:
      - image: patnaikshekhar/keda-pubsub-sample:1
        name: consumer
        env:
        - name: SUBSCRIPTION_NAME
          value: "mysubscription"
        - name: GOOGLE_APPLICATION_CREDENTIALS_JSON
          valueFrom:
            secretKeyRef:
              name: pubsub-secret
              key: GOOGLE_APPLICATION_CREDENTIALS_JSON
        - name: PROJECT_ID
          valueFrom:
            secretKeyRef:
              name: pubsub-secret
              key: PROJECT_ID
```
And this is the YAML for the scaled object

```yaml
apiVersion: keda.k8s.io/v1alpha1
kind: ScaledObject
metadata:
  name: pubsub-scaledobject
  namespace: keda-pubsub-test
  labels:
    deploymentName: keda-pubsub-go
spec:
  scaleTargetRef:
    deploymentName: keda-pubsub-go
  triggers:
  - type: gcp-pubsub
    metadata:
      subscriptionSize: "5"
      subscriptionName: "mysubscription" # Required 
      credentials: GOOGLE_APPLICATION_CREDENTIALS_JSON # Required
```

Finally, we're able to test the scaler by adding messages to the topic.

```sh
for x in {1..20}
do
gcloud beta pubsub topics publish $TOPIC_NAME \
  --message "Test Message ${x}"
done

```

You should now see the number of replicas increasing.