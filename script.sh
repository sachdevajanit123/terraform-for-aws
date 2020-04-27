#!/bin/bash

yum update -y
yum install httpd -y
echo "Hello Server 1" > /var/www/html/index.html
service httpd start