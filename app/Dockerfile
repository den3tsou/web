FROM --platform=${BUILDPLATFORM} golang:1.23-alpine

EXPOSE 8080

WORKDIR /app
COPY . .

RUN go install

CMD ["app"]

