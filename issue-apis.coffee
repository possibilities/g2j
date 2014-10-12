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

fetchJiraMetaIds = (client, issueType, projectName, componentName, callback) ->
  async.parallel {
    issueType: fetchCollectionAndFind.bind null, client.listIssueTypes.bind(client), { name: issueType }
    project: fetchCollectionAndFind.bind null, client.listProjects.bind(client), { key: projectName }
    component: fetchCollectionAndFind.bind null, client.listComponents.bind(client, projectName), { name: componentName }
  }, callback

module.exports =
  fetchAll: (clients, org, repo, callback) ->
    async.parallel
      gh: fetchGithub.bind null, clients.github, org, repo
      jira: fetchJira.bind null, clients.jira, org, repo
    , callback

  createOnJiraIfMissing: (client, projectName, issueType, componentName, issue, callback) ->
    if issue.jira then return callback null, issue

    fetchJiraMetaIds client, issueType, projectName, componentName, (err, ids) ->
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
