# coding: utf-8
from __future__ import print_function
import datetime
import json


def lambda_handler(event, context):
    return json.dumps(dict(message='Wa-i'))
