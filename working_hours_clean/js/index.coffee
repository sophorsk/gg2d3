
class Chart
  constructor: ()->
  ########
  #
  # Constant parameters
  #
  ########
  parameters: (()->
    #Map parameters
    ob =
      colors:
        white: "#FFF"
        lightblue: "#168CE5"
        darkblue: "#168CE5"
        rainbow: d3.scale.category20c().range()

      map:
        width: $(document).width()/3
        height: $(document).width()/3
        padding: 20

    ob.chart =
      width: $(document).width()-ob.map.width-50
      height: $(document).height()/3
      padding: 20

    ob.largeCat=
      width: $(document).height()/2
      height: $(document).height()/2
      r: $(document).height()/4-20
      padding: 20
      arcWidth: 20
      pie: d3.layout.pie().value((d)-> d.value)

    ob.largeCat.arc= d3.svg.arc()
      .outerRadius(ob.largeCat.r)
      .innerRadius(ob.largeCat.r*2/3)

    ob.stats=
      width: $(document).width()/3
      height: $(document).height()-ob.chart.height
      padding: 20

    ob.smallCat=
      width: $(document).height()/2
      height: $(document).height()/2
      r: $(document).height()/4-40
      padding: 20
      arcWidth: 30

    ob
  )()
  data: {}
  ########
  #
  # Variables
  #
  ########

  selectedCountry: "United States"
  selectedCategory: "Writing & Translation"
  ########
  #
  # d3.js charting objects
  #
  ########

  map: ((main)->
    ob =
      projection: d3.geo.mercator()
        .scale($(document).width()/3)
        .translate([$(document).width()/6,$(document).width()/4])
    ob.path = d3.geo.path().projection(ob.projection)
    ob.fisheye = d3.fisheye().radius(50).power(10)
    ob
  )(this)

  ########
  #
  # Set up the chart with initial data
  #
  ########

  createMap: (ob)->
    svg = d3.select("#map").append("svg")
     .attr("width", ob.parameters.map.width)
     .attr("height",ob.parameters.map.height)

    feature = svg.selectAll("path")
      .data(@data.worldCountries.features)
      .enter().append("path")
      .attr("class",(d)->
        if d.properties.name of ob.data.workingData
          if d.properties.name is ob.selectedCountry
            'selected'
          else
            'unselected'
        else
          "feature"
      )
      .attr("d",(d)-> ob.map.path(d))
      .each((d)-> d.org = d.geometry.coordinates)
      .on('mouseover', ob.onCountryClick)

    feature.append("title").text((d)-> d.properties.name)

    fishPolygon = (polygon)->
      _.map(polygon, (list)->
        _.map(list,(tuple)->
          p = ob.map.projection(tuple)
          c =  ob.map.fisheye({x : p[0], y : p[1]})
          ob.map.projection.invert([c.x, c.y])))

    refish = (e)->
      #Not sure why you have to get rid of 20
      #Padding maybe?
      x = e.offsetX
      y = e.offsetY
      #TODO: Still a little off on firefox
      x ?= e.screenX - $("#map svg").offset().left
      y ?= e.screenY - $("#map svg").offset().top

      ob.map.fisheye.center([x,y])
      svg.selectAll("path")
      .attr "d",(d)->
        clone = $.extend({},d)
        type = clone.geometry.type
        processed = if type is "Polygon" then fishPolygon(d.org) else _.map(d.org,fishPolygon)
        clone.geometry.coordinates = processed
        ob.map.path(clone)

    $("#map").on(i,refish) for i in ["mousemove","mousein","mouseout","touch","touchmove"]

  createChart: (ob)->
    weekChart = d3.select("#week")
      .append("svg")
      .attr("width", ob.parameters.chart.width)
      .attr("height", ob.parameters.chart.height)
      .append('g')
      .attr("id","weekChart")

    _.map _.range(7), (n)->
      str = "abcdefghi"
      weekChart.append("path").attr("class","area#{str[n]}l")
      weekChart.append("path").attr("class","area#{str[n]}r")


    weekChart.append("text").attr("class","yaxislabels") for i in [0..5]
    weekChart.append("text").attr("class","yaxistoplabel").text("# of workers")

    weekChart.selectAll("g.day")
      .data(["Monday", "Tuesday",
         "Wednesday", "Thursday", "Friday", "Saturday","Sunday"])
      .enter().append("text")
      .attr("x",(d,i)->(ob.parameters.chart.width-35)/7*(i+0.5)+35)
      .attr("dy",ob.parameters.chart.height-3)
      .attr("text-anchor","middle")
      .text((d)->d)

  createLargeCat: (ob)->

    w=ob.parameters.largeCat.width
    h=ob.parameters.largeCat.height
    r=ob.parameters.largeCat.r
    padding=ob.parameters.largeCat.padding

    $("#category_container").width(ob.parameters.chart.width)

    labeled_data = ({"label": "", "value": a} for a in [1])

    chart = d3.select("#main_category_container").append("svg")
      .attr("id","main_category")
      .data([labeled_data])
      .attr("width",w+padding)
      .attr("height",h+padding)
      .append("g").attr("transform","translate(#{w/2},#{h/2})")

    arcs = chart.append("g").attr("id","arcHolder")
      .selectAll("g.arc").data(ob.parameters.largeCat.pie)
      .enter()
      .append("g")
      .attr("class", "arc")

    arcs.append("path")
      .attr("d",ob.parameters.largeCat.arc)

    center = chart.append("g").attr("class","center")

    center.append("text")
      .text("Projects Completed")
      .attr("transform","translate(0,-7)")

    center.append("text")
      .attr("id","total")
      .text("Waiting...")
      .attr("transform","translate(0,7)")

    legend = d3.select("#main_category_container")
      .append("svg").attr("id","main_legend")
      .attr("width",w+padding)
      .attr("height",h+padding)

    chart.append("g").attr("class","hatch")
      .append("path").style("opacity",0.5)
      .attr("fill","black")


  createSmallCat: (ob)=>
    chart = d3.select("#sub_category").append("svg")
      .attr("height",ob.parameters.smallCat.height)
      .attr("width",ob.parameters.smallCat.width)

  createStats : (ob)=>
    stats = d3.select("#stats")
      .append("svg")
      .attr("width", ob.parameters.stats.width)
      .attr("height", ob.parameters.stats.height)
      .append('g')
      .attr("id","statsG")

    actual = (key for key, obj of c.data.workingData when not obj.zones)

    len =  _.max(_.pluck(actual,"length"))

    t = Math.round(ob.parameters.stats.width/len*2)

    stats.append("text")
      .attr("y",t)
      .style("font-size","#{t}px")
      .attr("id","country")

  createAlert: (ob)=>
    week = $("#week")
    weekOffset = week.offset()
    $("#alert").offset(
      left: weekOffset.left
      top: weekOffset.top-20
    ).width(week.width())

   ########
   #
   # Mouse events
   #
   ########

   onCountryClick: (d,i)=>
     clicked= d.properties.name
     if not (clicked of @data.workingData) then return
     @changeCountry(clicked,this)
   ########
   #
   # Change that which needs to be changed
   #
   ########

   changeCountry: (name,ob)=>
     @selectedCountry = name
     @updateMap(ob)
     @updateChart(ob)
     @updateLargeCat(ob)
     @updateSmallCat(ob)
     @updateStats(ob)
     @updateAlert(ob)

   updateAlert: (ob)=>
     hours = ob.data.workingData[@selectedCountry].hours
     if _.any(_.flatten(hours),(n)-> n<10)
       $("#alert").show()
       $("span#country").text(@selectedCountry)
     else
       $("#alert").hide()




   updateChart: (ob)=>
     instance = @data.workingData[@selectedCountry].hours
     flat  = _.flatten(instance)

     x = d3.scale.linear().domain([0, flat.length]).range([35, ob.parameters.chart.width])
     y = d3.scale.linear().domain([0, _.max(flat)]).range([ob.parameters.chart.height-30,5])

     weekChart = d3.select("#weekChart")

     #TODO: This looks wrong
     tickers= y.ticks(10)

     labels= weekChart.selectAll(".yaxislabels").data(tickers)
     labels.transition().delay(20)
       .attr("x", 30)
       .attr("y", y)
       .attr("text-anchor", "end")
       .text((d)-> d)
     labels.exit().remove()

     weekChart.select(".yaxistoplabel").transition().delay(20)
     .attr("y",20)

     extended = (flat[i..i+24] for i in [1..flat.length] by 24)

     mode = "basis"

     _.map _.range(7),(n)->
       str = "abcdefghi"

       weekChart.selectAll("path.area#{str[n]}l")
       .data([instance[n]]).transition().delay(20)
       .attr("fill", if n%2 is 0 then "#061F32" else "#168CE5")
       .attr("d",d3.svg.area()
         .x((d,i)-> x(i+24*n))
         .y0(y(0))
         .y1((d,i)-> y(d))
         .interpolate(mode,1000))

       weekChart.selectAll("path.area#{str[n]}r")
       .data([extended[n]]).transition().delay(20)
       .attr("fill", if n%2 is 0 then "#061F32" else "#168CE5")
       .attr("d",d3.svg.area()
         .x((d,i)-> x(i+1+24*n))
         .y0(y(0))
         .y1((d,i)-> y(d))
         .interpolate(mode))

     chartLine = weekChart.selectAll("path.thickline")
      .data([flat]).transition().delay(20)
      .attr("d",d3.svg.line()
        .x((d,i)-> x(i))
        .y((d,i)-> y(d))
        .interpolate(mode))

  updateLargeCat: (ob)=>
    instance = @data.workingData[@selectedCountry]["job_types"]

    data = {}

    for key,prop of instance
      data[key] = d3.sum(j for i,j of instance[key])

    labeled_data = ({"label": a, "value": b} for a,b of data)
      .sort((a,b)-> a.value < b.value)

    chart = d3.select("#main_category").data([labeled_data]).select("g")
    arcs = chart.select("g#arcHolder").selectAll("g.arc").data(ob.parameters.largeCat.pie)

    arcs.enter()
      .append("g").attr("class","arc")
      .append("path")

    pie_data = {}
    current = null

    changeCategory = () ->
      d3.select("g.hatch > path").transition()
        .attrTween("d",(d,i,a)->
          selected = pie_data[ob.selectedCategory]
          interpolater = d3.interpolate current, selected
          current = selected
          (t)-> ob.parameters.largeCat.arc(interpolater(t))
        )
      d3.selectAll("#main_legend>g>text").transition()
        .style("font-size",(d,i)->
          if d.label is ob.selectedCategory then "20px" else "10px")




    arcs.select("path")
      .attr("fill", (d,i) -> ob.parameters.colors.rainbow[i])
      .attr("d",(d,i) ->
        pie_data[d.data.label] = d
        if d.data.label is ob.selectedCategory
          current = d
        ob.parameters.largeCat.arc(d)
      )
      .on("mouseover", (d,i) ->
        ob.selectedCategory = d.data.label
        changeCategory()
        ob.updateSmallCat()
      )

    arcs.exit().remove()

    total = d3.sum(_.values(data))

    d3.select("text#total").text(total)

    legends = d3.select("#main_legend").selectAll("g")
      .data(labeled_data)

    l = legends.enter().append("g")

    l.append("rect")
    l.append("text")

    heightY = (d,i)-> i*20+ob.parameters.largeCat.height/3

    legends.select("rect")
      .attr("fill",(d,i)-> ob.parameters.colors.rainbow[i])
      .attr("y",heightY)
      .attr("height",10)
      .attr("width",10)

    legends.select("text")
      .text((d,i)->"#{d.label} - #{d.value}")
      .attr("y",(d,i)-> heightY(d,i)+10)
      .attr("x",14)

    legends.exit().remove()

    chart.select("g.hatch > path")
      .attr("d",ob.parameters.largeCat.arc(pie_data[ob.selectedCategory]))
    changeCategory()

  updateSmallCat: (ob)=>
    instance = @data.workingData[@selectedCountry].job_types[@selectedCategory]

    max = _.max(_.values(instance))
    p = ob.parameters.largeCat


  updateStats : ()->
    d3.select("#statsG text#country")
      .text(@selectedCountry)

  updateMap: (ob)->
    d3.selectAll("#map svg path")
      .transition().delay(10)
      .attr("class",(d) ->
        if d.properties.name of ob.data.workingData
          if d.properties.name is ob.selectedCountry
            "selected"
          else
            'unselected'
        else
          "feature"
    )

  ########
  #
  # Let there be light
  #
  ########

  begin: (c)->
    @createMap(c)
    @createChart(c)
    @createLargeCat(c)
    @createSmallCat(c)
    @createStats(c)
    @createAlert(c)

    @updateChart(c)
    @updateLargeCat(c)
    @updateSmallCat(c)
    @updateStats(c)
    @updateAlert(c)

c = new Chart()

i = 0
startQ = ()->
  i++
  if i is 2 then c.begin(c)

d3.json("data/working-data.json", (data)->
  c.data.workingData=data
  startQ()
)

d3.json("data/world-countries.json", (data)->
  c.data.worldCountries=data
  startQ()
)

$(window).resize(()->
  d = new Chart()
  $("#map").empty()
  $("#clock").empty()
  $("#week").empty()
  $("#stats").empty()
  d.begin(d)
)

check = ()->
  key for key, ob of c.data.workingData when not ob.zones?