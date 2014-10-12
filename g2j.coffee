_ = require 'underscore'
async = require 'async'
jira = require 'jira'
fs = require 'fs-extra'
path = require 'path'

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

fetchGithubRepoIssues = (client, org, name, callback) ->
  _fetchIssues = (client, org, name, paginationIndex, allIssues, cb) ->
    client.issues.repoIssues
      repo: name
      user: org
      page: paginationIndex
    , (err, issues) ->
      if err then return callback err
      if issues?.length
        allIssues = allIssues.concat issues
        _fetchIssues client, org, name, ++paginationIndex, allIssues, cb
      else
        cb null, allIssues

  _fetchIssues client, org, name, 1, [], (err, issues) ->
    if err then return callback err
    issues = _.reject issues, (issue) ->
      issue.pull_request?.url
    callback null, issues

fetchJiraProject = (client, org, name, callback) ->
  _fetchIssues = (client, org, name, allIssues, cb) ->
    options =
      startAt: allIssues.length
    client.searchJira "component = #{name}", options, (err, results) ->
      if err
        cb err
      else if issues = results.issues
        if issues.length
          allIssues = allIssues.concat issues
          _fetchIssues client, org, name, allIssues, cb
        else
          cb null, allIssues
      else
        callback new Error 'no issues found'

  _fetchIssues client, org, name, [], callback

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

createIssueIfMissing = (client, projectName, issueType, componentName, issue, callback) ->
  if issue.jira then return callback null, issue

  async.parallel {
    issueType: fetchCollectionAndFind.bind null, client.listIssueTypes.bind(client), { name: issueType }
    project: fetchCollectionAndFind.bind null, client.listProjects.bind(client), { key: projectName }
    component: fetchCollectionAndFind.bind null, client.listComponents.bind(client, projectName), { name: componentName }
  }, (err, ids) ->
    if err then return callback err
    trackMessage = "Tracked on GH: #{issue.gh.html_url}"

    newIssue =
      fields:
        summary: issue.gh.title
        description: trackMessage + "\n\n" + issue.gh.body
        project:
          id: ids.project
        components: [ id: ids.component ]
        issuetype:
          id: ids.issueType
        labels: ['open-source-tracking']

    client.addNewIssue newIssue, (err, _issue) ->
      issue.jira = _issue
      callback null, issue

findUnlinkedJiraIssues = (jiraIssues, linkedIssues) ->
  _.reject jiraIssues, (jiraIssue) ->
    _.find linkedIssues, (linkedIssue) ->
      jiraIssue.id == linkedIssue.jira?.id

fetchAllIssues = (clients, org, repo, callback) ->
  async.parallel
    gh: fetchGithubRepoIssues.bind null, clients.github, org, repo
    jira: fetchJiraProject.bind null, clients.jira, org, repo
  , callback

processProject = (clients, config, component, callback) ->
  console.log '\n -- processing repo:', component.repo

  fetchAllIssues clients, config.org, component.repo, (err, issues) ->
    if err then return callback err
    console.log '    github issues:', issues.gh.length
    console.log '    jira issues:', issues.jira.length

    linkedIssues = linkIssues component.repo, issues.gh, issues.jira

    unlinkedGhIssues = _.reject linkedIssues, (issue) -> issue.jira?
    console.log '    try to link issues:', unlinkedGhIssues.length

    createMissing = createIssueIfMissing.bind(null, clients.jira, component.project, config.issueType, component.repo)
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
