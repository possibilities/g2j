_ = require 'underscore'
async = require 'async'
jira = require 'jira'
fs = require 'fs-extra'
path = require 'path'
issueApis = require './issue-apis'

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

findJiraIssueForGhIssue = (name, ghIssue, jiraIssues) ->
  _.find jiraIssues, (jiraIssue) ->
    trackMessage = "Tracked on GH: #{ghIssue.html_url}"
    return jiraIssue.fields.description.indexOf(trackMessage) >= 0

linkIssues = (name, ghIssues, jiraIssues) ->
  _.reduce ghIssues, (linkedIssues, ghIssue) ->
    jiraIssue = findJiraIssueForGhIssue name, ghIssue, jiraIssues
    linkedIssues.push { gh: ghIssue, jira: jiraIssue }
    return linkedIssues
  , []

fetchCollectionAndFind = (fetcher, query, callback) ->
  fetcher (err, collection) ->
    if err then return callback err
    item = _.findWhere collection, query
    callback null, item?.id

findUnlinkedJiraIssues = (jiraIssues, linkedIssues) ->
  _.reject jiraIssues, (jiraIssue) ->
    _.find linkedIssues, (linkedIssue) ->
      jiraIssue.id == linkedIssue.jira?.id

processProject = (clients, config, component, callback) ->
  console.log '\n -- processing repo:', component.repo

  issueApis.fetchAll clients, config.org, component.repo, (err, issues) ->
    if err then return callback err
    console.log '    github issues:', issues.gh.length
    console.log '    jira issues:', issues.jira.length

    linkedIssues = linkIssues component.repo, issues.gh, issues.jira

    unlinkedGhIssues = _.reject linkedIssues, (issue) -> issue.jira?
    console.log '    try to link issues:', unlinkedGhIssues.length

    createMissing = issueApis.createOnJiraIfMissing.bind(issues, clients.jira, component.project, config.issueType, component.repo)
    async.map linkedIssues, createMissing, (err, linkedIssues) ->
      if err then return callback err
      unlinkedJiraIssues = findUnlinkedJiraIssues issues.jira, linkedIssues
      console.log '    unlinked jira issues:', JSON.stringify(_.pluck unlinkedJiraIssues, 'key')
      callback null, issues

processAllProjects = (clients, config, callback) ->
  process = processProject.bind(null, clients, config)
  async.mapSeries config.components, process, (err, components) ->
    if err then return callback err
    console.log '\ndone, processed', components.length, 'components'

processAllProjects { github, jira } , config, (err) ->
  if err
    console.error err
    process.exit 1
