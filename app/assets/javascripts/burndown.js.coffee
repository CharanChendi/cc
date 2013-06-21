$ ->
  $.each $(".burndownchart"), (i, chartContainer) ->
    constructBurndownChart chartContainer

constructBurndownChart = (chartContainer) ->
  projectURL = $(chartContainer).attr "data-url"
  
  d3.json projectURL, (project) ->
    chartData = projectBurndownData(project)

    nv.addGraph ->
      chart = nv.models.lineChart()

      chart.xAxis
        .axisLabel('Week (w)')
        .tickFormat(d3.format('d'))

      chart.yAxis
        .axisLabel('Task Units Remaining (t)')
        .tickFormat(d3.format(',.2f'))

      chart.tooltipContent (key, x, y, e, graph) ->
        byOrAt = if key is "Target Completion" then "by" else "at"
        "<h3>#{key}</h3>
        <p>#{y} remaining #{byOrAt} Week #{x}</p>"

      ###
      If under a tab, make sure tab changes re-render chart
      ###
      tab = $(chartContainer).parents ".tab-pane"
      if tab.length 
        tab.each (i,e) ->
          t = $("a[href='##{$(e).attr("id")}'][data-toggle]")
          t.on "shown", -> chart.update()

      d3.select($(chartContainer).children("svg")[0])
        .datum(chartData)
        .transition().duration(500)
        .call(chart)

      nv.utils.windowResize(chart.update)

projectBurndownData = (project) ->
  targetSeries = 
    key:    "Target Completion"
    values: targetCompletionData(project)
    color:  "#666666"
  
  completedSeries =
    key:    "Actual Completion"
    values: actualCompletionData(project)
    color:  progressColour(project.progress)

  projectedSeries =
    key:    "Projected Completion"
    values: projectedCompletionData(project)
    color:  "#BBB"

  seriesToPlot = [targetSeries]

  if projectCommenced(project)
    seriesToPlot.push(series) for series in [projectedSeries, completedSeries]

  seriesToPlot

projectCommenced = (project) ->
  afterStartDate = moment(new Date()) >= moment(project.unit.start_date)
  tasksCompleted = project.completed_tasks_weight > 0
  afterStartDate and tasksCompleted

targetCompletionData = (project) ->
  startDate   = moment(project.unit.start_date)
  endDate     = moment(project.unit.end_date)
  cutOffWeek  = moment(endDate).diff startDate, 'weeks'
  
  totalWeight = project.total_task_weight

  tasks = project.tasks.filter((task) -> task.task_definition.required)
          .sort byTargetDate

  weekVsTaskUnitsCompleted  = weekTaskUnitsCompleted(tasks, startDate, cutOffWeek, 'target_date')
  taskCompletionVsWeek      = countdownRemainingWeight  weekVsTaskUnitsCompleted,
                                                        totalWeight

  taskCompletionVsWeek

actualCompletionData = (project) ->
  startDate   = moment(project.unit.start_date)
  endDate     = moment(project.unit.end_date)
  cutOffDate  = if moment() > endDate then endDate else moment()
  cutOffWeek  = cutOffDate.diff startDate, 'weeks'

  totalWeight = project.total_task_weight

  tasks = project.tasks.filter((task) -> task.task_definition.required and task.status is "complete")
          .sort byCompletionDate

  weekVsTaskUnitsCompleted  = weekTaskUnitsCompleted(tasks, startDate, cutOffWeek, 'completion_date')
  taskCompletionVsWeek      = countdownRemainingWeight  weekVsTaskUnitsCompleted,
                                                        totalWeight

  taskCompletionVsWeek

projectedCompletionData = (project) ->
  startDate   = moment(project.unit.start_date)
  endDate     = moment(project.unit.end_date)
  currentDate = if moment() > endDate then endDate else moment()
  currentWeek = currentDate.diff(startDate, 'weeks')
  cutOffDate  = if moment() <= endDate then endDate else moment()
  endWeek     = cutOffDate.diff startDate, 'weeks'

  totalWeight     = project.total_task_weight
  completionRate  = project.completed_tasks_weight / currentWeek

  weekVsTaskUnitsCompleted  = []

  week = 1; remainingWeight = totalWeight

  while week <= endWeek and remainingWeight > 0
    remainingWeight -= completionRate

    if remainingWeight < 0
      weekVsTaskUnitsCompleted[week] = remainingWeight + completionRate
    else
      weekVsTaskUnitsCompleted[week] = completionRate

    week++

  countdownRemainingWeight  weekVsTaskUnitsCompleted, totalWeight


weekTaskUnitsCompleted = (tasks, startDate, cutOffWeek, taskDate) ->
  weekTaskWeightCompleted = []
  weekTaskWeightCompleted[i] = 0 for i in [0..cutOffWeek]

  tasks.forEach (task) ->
    completionDate = if taskDate is 'target_date' then task.task_definition.target_date else task.completion_date
    dueWeek = moment(completionDate).diff startDate, 'weeks'
    weekTaskWeightCompleted[dueWeek] += task.weight

  weekTaskWeightCompleted

countdownRemainingWeight = (weekTaskWeightCompleted, totalWeight) ->
  completionVsWeek = [{x: 0, y: totalWeight}]
  remainingWeight = totalWeight

  weekTaskWeightCompleted.forEach (completed, i) ->
    remainingWeight -= completed
    completionVsWeek.push {x: i, y: remainingWeight}

  completionVsWeek

byTargetDate = (taskA, taskB) ->
  taskADate = moment(taskA.task_definition.target_date)
  taskBDate = moment(taskB.task_definition.target_date)
  if taskADate is taskBDate
    0
  else
    if taskADate > taskBDate then 1 else -1

byCompletionDate = (taskA, taskB) ->
  taskADate = moment(taskA.completion_date)
  taskBDate = moment(taskB.completion_date)
  if taskADate is taskBDate
    0
  else
    if taskADate > taskBDate then 1 else -1

progressColour = (progress) ->
  switch progress
    when "ahead"        then "#48842c" # Twitter Bootstrap @green
    when "on_track"     then "#049cdb" # Twitter Bootstrap @blue
    when "behind"       then "#f89406" # Twitter Bootstrap @orange
    when "danger"       then "#9d261d" # Twitter Bootstrap @red
    when "doomed"       then "#000000" # Black
    when "not_started"  then "#888888" # Grey