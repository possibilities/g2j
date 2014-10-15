_ = require 'underscore'
async = require 'async'

fetchGithub = (client, org, name, callback) ->
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

fetchJira = (client, org, name, callback) ->
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

fetchJiraMetaIds = (client, issueType, project, callback) ->
  async.parallel {
    issueType: fetchCollectionAndFindIdByQuery.bind null
      , client.listIssueTypes.bind(client)
      , { name: issueType }
    project: fetchCollectionAndFindIdByQuery.bind null
      , client.listProjects.bind(client)
      , { key: project.jiraProject }
    component: fetchCollectionAndFindIdByQuery.bind null
      , client.listComponents.bind(client, project.jiraProject)
      , { name: project.name }
  }, callback

fetchCollectionAndFindIdByQuery = (fetcher, query, callback) ->
  fetcher (err, collection) ->
    if err then return callback err
    item = _.findWhere collection, query
    callback null, item?.id

addJiraIssue = (issue, ids, config, callback) ->
  trackMessage = "Tracked on GH: #{issue.html_url}"
  newIssue =
    fields:
      summary: issue.title
      description: trackMessage + "\n\n" + issue.body
      project:
        id: ids.project
      components: [ id: ids.component ]
      issuetype:
        id: ids.issueType
      labels: config.labels
  client.addNewIssue newIssue, callback

module.exports =
  fetchAll: (clients, org, repo, callback) ->
    async.parallel
      gh: fetchGithub.bind null, clients.github, org, repo
      jira: fetchJira.bind null, clients.jira, org, repo
    , callback

  addToJiraIfMissing: (client, project, config, issue, callback) ->
    if issue.jiraIssue then return callback null, issue

    fetchJiraMetaIds client, config.issueType, project, (err, ids) ->
      if err then return callback err

      addJiraIssue issue, ids, config, callback
