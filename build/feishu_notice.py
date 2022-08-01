from typing import Iterator
import hashlib
import base64
import hmac
import time
import argparse
import git
import os
from datetime import datetime

import requests

MAX_LENGTH = 30
CURRENT_PATH = os.path.dirname(os.path.abspath(__file__))
print(CURRENT_PATH)
ROOT_PATH = "/".join([CURRENT_PATH, ".."])
OWNER = 'tapdata'
REPO = 'tapdata-enterprise'


class GithubActionApi:

    def __init__(self, token: str, owner: str, repo: str, job: str):
        self.base_url = "https://api.github.com"
        self.headers = {"Authorization": f"token {token}", "Accept": "application/vnd.github+json"}
        self.owner = owner
        self.repo = repo
        self.job = job

    def _get_jobs(self):
        response = requests.get(f"{self.base_url}/api/v3/repos/{self.owner}/{self.repo}/jobs/{self.job}", headers=self.headers)
        if response.status_code == 200:
            return response.json().get("steps")
        else:
            raise Exception(f"Failed to get jobs for {self.owner}/{self.repo}")

    @property
    def failed_steps(self):
        steps = self._get_jobs()
        failed_steps = []
        for step in steps:
            status = step.get("status")
            name = step.get("name")
            if status == "failure":
                failed_steps.append(name)
        return failed_steps


class Git:

    def __init__(self, dir_path):
        print(dir_path)
        self.repo = git.Repo(dir_path)
        self.branch = self.repo.head.reference

    @property
    def commit_time(self):
        return datetime.fromtimestamp(self.branch.commit.committed_date).strftime("%Y-%m-%d %H:%M:%S")

    @property
    def commit_message(self):
        return self.branch.commit.message.replace('\n', '')

    @property
    def commit_author(self):
        return self.branch.commit.author.name

    @property
    def commit_author_email(self):
        return self.branch.commit.author.email


class Args:

    def __init__(self):
        self.git_obj = Git(ROOT_PATH)
        parse = argparse.ArgumentParser(description="send error info to feishu.")
        parse.add_argument('--branch', dest="branch", required=True, type=str, help="github branch")
        parse.add_argument("--runner", dest="runner", required=True, type=str, help="github action runner name")
        parse.add_argument("--detail_url", dest="detail_url", required=True, type=str, help="detail url")
        parse.add_argument("--secret", dest="secret", required=True, type=str, help="feishu bot secret key")
        parse.add_argument("--bot_webhook", dest="bot_webhook", required=True, type=str, help="feishu bot webhook url")
        parse.add_argument("--token", dest="token", required=True, type=str, help="github personal token")
        parse.add_argument("--job_id", dest="job_id", required=True, type=str, help="github action job id", default="Build")
        parse.add_argument("--person_in_charge", dest="person_in_charge", required=True, type=str, help="person_in_charge of module")
        self.args = parse.parse_args()
        self.github_api = GithubActionApi(self.args.token, OWNER, REPO, self.args.job_id)

    @property
    def branch(self):
        return self.args.branch

    @property
    def runner(self):
        return self.args.runner

    @property
    def commit_time(self):
        return self.git_obj.commit_time

    @property
    def commit_message(self):
        return self.git_obj.commit_message

    @property
    def commit_author_email(self):
        return self.git_obj.commit_author_email

    @property
    def commit_author(self):
        return self.git_obj.commit_author

    @property
    def modules(self):
        return self.github_api.failed_steps

    @property
    def error_message(self):
        err_msg = self.args.error_message
        if self.args.error_message > MAX_LENGTH:
            err_msg = self.args.error_message[27:] + "..."
        return err_msg

    @property
    def detail_url(self):
        return self.args.detail_url

    @property
    def secret(self):
        return self.args.secret

    @property
    def bot_webhook(self):
        return self.args.bot_webhook

    @property
    def person_in_charge(self):
        return self.args.person_in_charge


class FeishuMessage:
    """
    @describe: A bot to send message to feishu
    @author: Jerry
    @file: feishu_notice.py
    @version:
    @time: 2022/07/29
    """

    def __init__(self,
                 webhook: str,
                 title: str,
                 content: Iterator[Iterator],
                 secret: str = "",
                 title_color: str = "red") -> None:
        """
        @param webhook: bot webhook
        @param title: message title
        @param title_color: title color if FeishuMessage.send_card method is call
        @param content:
            message content data struct,
            example:
                [[{"tag": "text", "text": "项目有更新: "}, {"tag": "a", "text": "请查看", "href": "https://xxx.com/"}]]
        """
        self.webhook = webhook
        self.title = title
        self.content = content
        self.headers = {"Content-Type": "application/json"}
        self.secret = secret
        self.title_color = title_color

    def _get_auth_sign(self):
        timestamp = str(int(time.time()))
        string_to_sign = '{}\n{}'.format(timestamp, self.secret)
        hmac_code = hmac.new(string_to_sign.encode("utf-8"), digestmod=hashlib.sha256).digest()
        sign = base64.b64encode(hmac_code).decode('utf-8')
        return sign, timestamp

    def _make_request_body(self, msg_content: dict):
        body = {
            "msg_type": "post",
        }
        body.update(msg_content)
        if self.secret:
            sign, timestamp = self._get_auth_sign()
            body.update({
                "timestamp": timestamp,
                "sign": sign
            })
        return body

    def _make_send_message_request_body(self):
        body = {
            "content": {
                "post": {
                    "zh_cn": {
                        "title": self.title,
                        "content": self.content
                    }
                }
            }
        }
        return self._make_request_body(body)

    def _make_send_card_request_body(self):
        body = {
            "msg_type": "interactive",
            "card": {
                "config": {
                    "wide_screen_mode": True,
                    "enable_forward": True
                },
                "header": {
                    "template": self.title_color,
                    "title": {
                        "content": self.title,
                        "tag": "plain_text"
                    }
                },
                "elements": self.content
            }
        }
        return self._make_request_body(body)

    def _request(self, data):
        res = requests.post(self.webhook, json=data, headers=self.headers)
        if res.json().get("StatusCode") == 0:
            print("send message success.")
        else:
            print("send message failed")
            print(res.text)

    def send_message(self):
        data = self._make_send_message_request_body()
        self._request(data)

    def send_card(self):
        data = self._make_send_card_request_body()
        self._request(data)


class Card:

    def __init__(self, args_obj: Args, person_in_charge: dict):
        self.args_obj = args_obj
        self.person_in_charge = person_in_charge

    def _get_person_in_charge(self, module):
        if not isinstance(self.person_in_charge, dict):
            print("person_in_charge map is not provided")
            return ""
        elif self.person_in_charge.get(module, None):
            return self.person_in_charge[module]
        else:
            print(f"{module} no person_in_charge")
            return "no person_in_charge"

    def _format_fields(self):
        fields = []
        for module in self.args_obj.modules:
            fields += [{
                "is_short": False,
                "text": {
                    "content": "",
                    "tag": "lark_md"
                }
            }, {
                "is_short": True,
                "text": {
                    "content": f"**报错模块**\n{module}",
                    "tag": "lark_md"
                }
            }, {
                "is_short": True,
                "text": {
                    "content": f"**模块负责人**\n{self._get_person_in_charge(module)}",
                    "tag": "lark_md"
                }
            }]
        fields = [{
            "is_short": True,
            "text": {
                "content": f"**分支名称**\n{args.branch}",
                "tag": "lark_md"
            }
        }, {
            "is_short": True,
            "text": {
                "content": f"**构建任务**\n{args.runner}",
                "tag": "lark_md"
            }
        }] + fields + [{
            "is_short": False,
            "text": {
                "content": "",
                "tag": "lark_md"
            }
        }, {
            "is_short": True,
            "text": {
                "content": f"**提交人**\n{args.commit_author}",
                "tag": "lark_md"
            }
        }, {
            "is_short": True,
            "text": {
                "content": f"**提交人邮箱**\n{args.commit_author_email}",
                "tag": "lark_md"
            }
        }]
        return {
            "fields": fields,
            "tags": "div",
        }

    def _format_error_message_detail_button(self):
        return {
            "actions": [{
                "tag": "button",
                "text": {
                    "content": "点击查看报错信息",
                    "tag": "lark_md"
                },
                "url": self.args_obj.detail_url,
                "type": "default",
                "value": {}
            }],
            "tag": "action"
        }

    def todict(self):
        return [
            self._format_fields(),
            self._format_error_message_detail_button(),
        ]


if __name__ == "__main__":
    args = Args()
    card = Card(args, args.person_in_charge)

    FeishuMessage(args.bot_webhook, "企业版 自动构建失败通知", card.todict(), secret=args.secret).send_card()
