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
    issues = issueData.linkIssues issues

    unlinkedGhIssues = _.reject issues.gh, (issue) -> issue.jiraIssue?
    console.log '    unlinked gh issues:', unlinkedGhIssues.length

    unlinkedJiraIssues = _.reject issues.jira, (issue) -> issue.ghIssue?
    console.log '    unlinked jira issues:', unlinkedJiraIssues.length

    addMissing = issueApis.addToJiraIfMissing.bind issueApis
      , clients.jira
      , project
      , config

    async.map issues.gh, addMissing, (err, ghIssues) ->
      if err then return callback err
      issues.gh = ghIssues
      callback null, issues

processAllProjects = (clients, config, callback) ->
  process = processProject.bind null, clients, config
  async.mapSeries config.projects, process, (err, projectIssues) ->
    if err then return callback err
    console.log '\ndone, processed', projectIssues.length, 'components'

processAllProjects { github, jira },  config, (err) ->
  if err
    console.error err
    process.exit 1
