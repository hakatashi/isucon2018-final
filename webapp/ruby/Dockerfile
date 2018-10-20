FROM ubuntu:18.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y build-essential git-core tzdata ruby ruby-dev ruby-bundler libmysqlclient-dev
RUN apt-get install -y mysql-client
ENV TZ=Asia/Tokyo
