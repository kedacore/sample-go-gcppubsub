FROM alpine

RUN apk update && \
    apk add --no-cache make ca-certificates git && \
    update-ca-certificates
    
COPY ./app /app

ENTRYPOINT [ "/app" ]
