# g2j

sync issues between github <-> jira

# summary

quick and dirty "syncing" of github and jira issues. right now we just copy unsync'd issues from gh to a new issue is jira, tag it with a url back to the GH issue and leave it alone. the operation is idempotent so you can run it over and over without any effect unless new data is available.

# configuration

Create a config file at `~/.g2j.json`

```json
{
  "org": "Versal",
  "issueType": "Story",
  "projects": [{
    "name": "sdk",
    "jiraProject": "WP"
  }],
  "github": {
    "version": "3.0.0"
  },
  "labels": [
    "open-source-tracking"
  ],
  "jira": {
    "protocol": "https",
    "host": "versal.atlassian.net",
    "port": 443,
    "username": "jirausename",
    "password": "jirapassword",
    "version": "2"
  }
}
```

# usage

```shell
npm install
npm start
```

## todo

copy comments over as they come in
track title and description changes
sync progress in one direction or another
