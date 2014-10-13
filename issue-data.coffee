_ = require 'underscore'

findJiraIssueForGhIssue = (ghIssue, jiraIssues) ->
  # try to avoid side effects
  ghIssue = _.clone ghIssue
  jiraIssues = _.clone jiraIssues

  _.find jiraIssues, (jiraIssue) ->
    trackMessage = "Tracked on GH: #{ghIssue.html_url}"
    return jiraIssue.fields.description.indexOf(trackMessage) >= 0

module.exports =
  linkIssues: (issues) ->
    # try to avoid side effects
    issues = _.clone issues

    # we're mutating issues here but it's a clone, ok afaic
    _.each issues.gh, (ghIssue) ->
      jiraIssue = findJiraIssueForGhIssue ghIssue, issues.jira
      if jiraIssue
        ghIssue.jiraIssue = jiraIssue
        jiraIssue.ghIssue = _.clone ghIssue

    return issues
