package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	log.Print("Web up.")

	ch := make(chan os.Signal, 1)

	signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM)

	<-ch

	log.Print("Shutting down.")
}
