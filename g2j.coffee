_ = require 'underscore'
async = require 'async'
fs = require 'fs-extra'
path = require 'path'
issueApis = require './issue-apis'
issueData = require './issue-data'

GitHubApi = require 'github'
JiraApi = require('jira').JiraApi

config = fs.readJsonSync path.join process.env.HOME, '.g2j.json'

jira = new JiraApi config.jira.protocol,
  config.jira.host,
  config.jira.port,
  config.jira.username,
  config.jira.password,
  config.jira.version

github = new GitHubApi
  version: config.github.version

if config.github.username && config.github.password
  github.authenticate
    type: 'basic'
    username: config.github.username
    password: config.github.password

processProject = (clients, config, project, callback) ->
  console.log '\n -- processing repo:', project.name

  issueApis.fetchAll clients, config.org, project.name, (err, issues) ->
    if err then return callback err
    console.log '    github issues:', issues.gh.length
    console.log '    jira issues:', issues.jira.length

    linkedIssues = issueData.linkIssues project.name, issues

    unlinkedGhIssues = _.reject linkedIssues, (issue) -> issue.jira?
    console.log '    try to link issues:', unlinkedGhIssues.length

    createMissing = issueApis.createOnJiraIfMissing.bind issues
      , clients.jira
      , project
      , config

    async.map linkedIssues, createMissing, (err, linkedIssues) ->
      if err then return callback err
      unlinkedJiraIssues = issueData.findUnlinkedJiraIssues issues.jira, linkedIssues
      console.log '    unlinked jira issues:'
        , JSON.stringify(_.pluck unlinkedJiraIssues, 'key')
      callback null, issues

processAllProjects = (clients, config, callback) ->
  process = processProject.bind(null, clients, config)
  async.mapSeries config.projects, process, (err, projectIssues) ->
    if err then return callback err
    console.log '\ndone, processed', projectIssues.length, 'components'

processAllProjects { github, jira },  config, (err) ->
  if err
    console.error err
    process.exit 1
