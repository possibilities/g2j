_ = require 'underscore'

findJiraIssueForGhIssue = (name, ghIssue, jiraIssues) ->
  _.find jiraIssues, (jiraIssue) ->
    trackMessage = "Tracked on GH: #{ghIssue.html_url}"
    return jiraIssue.fields.description.indexOf(trackMessage) >= 0

module.exports =
  linkIssues: (name, issues) ->
    _.reduce issues.gh, (linkedIssues, ghIssue) ->
      jiraIssue = findJiraIssueForGhIssue name, ghIssue, issues.jira
      linkedIssues.push { gh: ghIssue, jira: jiraIssue }
      return linkedIssues
    , []

  findUnlinkedJiraIssues: (jiraIssues, linkedIssues) ->
    _.reject jiraIssues, (jiraIssue) ->
      _.find linkedIssues, (linkedIssue) ->
        jiraIssue.id == linkedIssue.jira?.id

