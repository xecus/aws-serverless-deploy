#!/bin/bash
pip install -r requirements.txt -t .
zip -r upload.zip *
aws lambda update-function-code --function-name taguroSlackSystem --zip-file fileb://./upload.zip
rm upload.zip
