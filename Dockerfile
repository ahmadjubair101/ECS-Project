FROM golang:1.26.3-alpine AS builder

RUN apk --update add ca-certificates

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY . ./

RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o gatus .

FROM alpine:latest

RUN apk add --no-cache ca-certificates wget

COPY --from=builder /app/gatus /gatus
COPY --from=builder /app/config.yaml /config/config.yaml

EXPOSE 8080

ENTRYPOINT ["/gatus"]
