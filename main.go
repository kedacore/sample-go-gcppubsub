package main

import (
	"context"
	"log"
	"os"

	"cloud.google.com/go/pubsub"
	"google.golang.org/api/option"
)

func main() {
	subscriptionName := os.Getenv("SUBSCRIPTION_NAME")
	projectID := os.Getenv("PROJECT_ID")
	credentialsJSON := os.Getenv("GOOGLE_APPLICATION_CREDENTIALS_JSON")

	ctx := context.Background()
	client, err := pubsub.NewClient(ctx, projectID, option.WithCredentialsJSON([]byte(credentialsJSON)))
	if err != nil {
		panic(err)
	}
	sub := client.Subscription(subscriptionName)

	log.Printf("Waiting for messages in subscription %s", subscriptionName)

	err = sub.Receive(ctx, func(ctx context.Context, m *pubsub.Message) {
		log.Printf("Message received %s", string(m.Data))
		m.Ack()
	})

	if err != context.Canceled {
		panic(err)
	}
}
