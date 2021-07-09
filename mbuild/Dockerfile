FROM python

# install docker
RUN apt update
RUN apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
RUN add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
RUN apt update
RUN apt install -y docker-ce-cli

# install mbuild dependency
RUN pip3 install chevron pyyaml
ADD utils/ /home/utils/

WORKDIR /home/
