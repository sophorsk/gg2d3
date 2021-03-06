#Compare chart methods and objects
compare =
  rainbow:  _.flatten([d3.scale.category20().range(),
    d3.scale.category20b().range(),
    d3.scale.category20c().range()])
  log_q: false
  navigate: ()->
    str = selectedCountries.join('/')
    while str.slice(-2) is "//"
      str = str.slice(0,str.length-1)
    console.log(str,encodeURI(str))
    route.navigate(encodeURI("#/compare/#{compare.log_q}/#{str}"))

selectedCountries = (()->
    arr = ["United States", "Canada", "Russia", "India"]
    arr.push(null) for i in _.range(compare.rainbow.length-arr.length)
    arr)()

toggleSelectedCountry = (country)->
  if not data.working[country]? or not data.working[country].local_hours?
    return;
  i = selectedCountries.indexOf(country)
  if i is -1
    selectedCountries[selectedCountries.indexOf(null)]= country
  else if _.filter(selectedCountries, (n)-> not _.isNull(n)).length isnt 1
    selectedCountries[i] = null
  compare.navigate()
  updateCompareChart()

updateActivityData = ()->
    data.activity = {absolute: [], normal: []}

    transform = (d)->
      if compare.log_q
        if d is 0
          0
        else
          Math.log(d)
      else d

    for c in selectedCountries when not _.isNull(c)

      instance =  _.flatten(data.working[c].local_hours)
      enumerated = ({x: i*60*60, y: transform(instance[i])} for i in _.range(instance.length))
      data.activity.absolute.push(
        data: enumerated
        color: compare.rainbow[selectedCountries.indexOf(c)]
        name: c
      )

      tmp =  _.chain(data.working[c].local_hours)
        .flatten().value()

      instance = _.map(tmp,(d)-> d/data.working[c].total)
      enumerated = ({x: i*60*60, y: instance[i]} for i in _.range(instance.length))
      data.activity.normal.push(
        data: enumerated
        color: compare.rainbow[selectedCountries.indexOf(c)]
        name: c
      )

    data.activity

createCompareChart = ()->
  createCompareMap()
  createCompareLines()
  createCompareLegend()
  createControls()

createControls = ()->
  $(".active-ex").tooltip(
    placement: "right"
    title: "Active here means that the worker billed time for an hourly project. Fixed rate projects are not included in these graphs."
  )
  $("#radio-scale").button()

  log_update = ()->
    updateActivityData()
    updateCompareChart()
    compare.navigate()

  $("#radio-scale > button:first").click(()->
    if compare.log_q
      compare.log_q = false
      log_update()
  )

  $("#radio-scale > button:last").click(()->
    if !compare.log_q
      compare.log_q = true
      log_update()
  )

  $("#country_typeahead").typeahead(
    source: _.keys(data.working)
  )
  .change((e)->
    country = this.value
    if country and data.working[country]?
      toggleSelectedCountry(country)
      this.value = ""
  )

updateCompareChart = ()->
  updateCompareMap()
  updateCompareLines()
  updateCompareLegend()

  if compare.log_q
    $("#radio-scale > button:last").button('toggle')
  else
    $("#radio-scale > button:first").button('toggle')

createCompareMap =  ()->
  size = $("#comparemap").parent().width()

  compare.map = d3.select("#comparemap").append("svg")
    .attr("height",size*0.7)
    .attr("width",size)

  compare.map.projection =  d3.geo.mercator()
    .scale(size)
    .translate([size/2,size/2])

  compare.map.path = d3.geo.path().projection(compare.map.projection)
  compare.map.fisheye = d3.fisheye().radius(50).power(10)


  feature = compare.map.selectAll("path")
    .data(data.countries.features).enter()
      .append("path")
    .attr("class",(d)->
      if d.properties.name of data.working and data.working[d.properties.name].local_hours?
        "selectable"
      else
        "feature grey"
    )
    .attr("d",compare.map.path)
    .each((d)-> d.org = d.geometry.coordinates)
    .on('click', (d,i)->
      clicked= d.properties.name
      toggleSelectedCountry(clicked)
    )

  feature.each((d,i)->
    $(this).tooltip(
      title: d.properties.name
    )
  )

  fishPolygon = (polygon)->
    _.map(polygon, (list)->
      _.map(list,(tuple)->
        p = compare.map.projection(tuple)
        c =  compare.map.fisheye({x : p[0], y : p[1]})
        compare.map.projection.invert([c.x, c.y])))

  refish = (e)->
    x = e.offsetX
    y = e.offsetY
    #TODO: Still a little off on firefox
    m = $("#comparemap > svg").offset()
    if not x?
      totalOffsetX = 0
      totalOffsetY = 0
      currentElement = this
      while true
        totalOffsetX += currentElement.offsetLeft
        totalOffsetY += currentElement.offsetTop
        break if (currentElement = currentElement.offsetParent)

      x = e.pageX - totalOffsetX
      y = e.pageY - totalOffsetY


    compare.map.fisheye.center([x,y])
    compare.map.selectAll("path")
     .attr("d",(d)->
      type = d.geometry.type
      processed = if type is "Polygon" then fishPolygon(d.org) else _.map(d.org,fishPolygon)
      ob =
        geometry:
          type: type
          coordinates: processed
        id: d.id
        properties: d.properties
        type: d.type
      compare.map.path ob
    )

  $("#comparemap").on(i,refish) for i in ["mousemove","mousein","mouseout","mouseover","touch","touchmove"]

updateCompareMap = ()->
  compare.map.selectAll("path")
    .transition().delay(10)
    .attr("fill",(d)->
      i = selectedCountries.indexOf(d.properties.name)
      if i isnt -1
      then compare.rainbow[i]
      else "white"
    )
    .attr("stroke","black")

createCompareLines = ()->
  updateActivityData()

  compare.absolute = new Rickshaw.Graph({
      renderer: "line"
      element: document.querySelector("#absolute")
      height: $("#comparemap").parent().height()*0.5
      width: $("#absolute").parent().width()
      series: data.activity.absolute
    })

  compare.normal = new Rickshaw.Graph({
      renderer: "line"
      element: document.querySelector("#normalized")
      height: $("#comparemap").parent().height()*0.5
      width: $("#absolute").parent().width()
      series: data.activity.normal
    })

  compare.absolute.render()
  compare.normal.render()

  ticks = "glow"
  week=["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
  time = new Rickshaw.Fixtures.Time
  timer = time.unit("day")
  a = timer.formatter
  timer.formatter = (d)-> week[a(d)-1]

  xaxa ={ graph: compare.absolute, ticksTreatment: ticks, timeUnit: timer, tickFormat: Rickshaw.Fixtures.Number.formatKMBT }

  yaxa = {graph: compare.absolute,tickFormat: Rickshaw.Fixtures.Number.formatKMBT}

  xaxn ={ graph: compare.normal, ticksTreatment: ticks, timeUnit: timer, tickFormat: Rickshaw.Fixtures.Number.formatKMBT }

  yaxn = {graph: compare.normal,tickFormat: (n)->
    if n is 0 then "" else "#{n*100}%"

  }

  compare.absolute.xAxis = new Rickshaw.Graph.Axis.Time xaxa
  compare.absolute.yAxis = new Rickshaw.Graph.Axis.Y yaxa

  compare.normal.xAxis = new Rickshaw.Graph.Axis.Time xaxn
  compare.normal.yAxis = new Rickshaw.Graph.Axis.Y yaxn

  compare.absolute.xAxis.render()
  compare.absolute.yAxis.render()
  compare.normal.yAxis.render()
  compare.normal.xAxis.render()

  compare.absolute.hover = new Rickshaw.Graph.HoverDetail({
    graph: compare.absolute,
    xFormatter: ((x)->
      h = x/3600
      day = week[Math.floor(h/24)]
      hour = h%24
      this.time = "#{day}, #{hour}:00-#{(hour+1)%24}:00"
      null
    )
    yFormatter: (y)->
      t = ""
      if compare.log_q
        t += Math.round(y*100)/100 +  " log workers online, which is about #{Math.round(Math.exp(y))} workers"
      else
        t += Math.floor(y) + " workers online"
      t+"<br />"+this.time
  })

  compare.normal.hover = new Rickshaw.Graph.HoverDetail({
    graph: compare.normal,
    xFormatter: ((x)->
      h = x/3600
      day = week[Math.floor(h/24)]
      hour = h%24
      this.time = "#{day}, #{hour}:00-#{(hour+1)%24}:00"
      null
    )
    yFormatter: (y)->
      p = Math.round(y*100*100)/100

      "#{p}% of registered workers were active <br /> #{this.time}"
  })

  #Errors get thrown all over the place here. Unsure why.
  #Still works though.
  try
    compare.absolute.hover.render()
  catch err

  try
    compare.normal.hover.render()
  catch err


updateCompareLines = ()->
  d = updateActivityData()
  m = compare.absolute.series.length
  n = d.absolute.length

  for i in _.range(d3.max([m,n]))
      if i < n
        compare.absolute.series[i]= d.absolute[i]
        compare.normal.series[i]= d.normal[i]
      else
        delete compare.absolute.series[i]
        delete compare.normal.series[i]

  compare.absolute.update()
  compare.normal.update()

createCompareLegend = ()->

updateCompareLegend = ()->
  legend = $("#comparelegend")
  #hack
  legend.empty()

  deselect = (country)->
    (e)->
      toggleSelectedCountry(country)
  for i in _.range(selectedCountries.length)
    cq = selectedCountries[i]
    if cq
      c = $("<div>")
      box = $("<div>").css
        height: 10
        width: 10
        display: "inline-block"
        "margin-right": "10px"
        "background-color":compare.rainbow[i]
      remover = $("<i>").addClass("icon-remove").css("float","right")

      c.text(cq).prepend(box).append(remover).click(deselect(cq))

      legend.append(c)
