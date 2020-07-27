FROM ubuntu

ENV AWS_ACCESS_KEY_ID=""
ENV AWS_SECRET_ACCESS_KEY=""

RUN apt-get update && \
    apt-get install -y openssh-client jq python3-pip

COPY id_rsa /root/.ssh/id_rsa
RUN chmod 600 /root/.ssh/id_rsa

COPY bash.sh /bash.sh

RUN pip3 install awscli

# ENTRYPOINT pwd
# ENTRYPOINT ./bash.sh $0 $1 $2