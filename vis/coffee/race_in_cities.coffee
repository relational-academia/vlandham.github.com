
@showCity = (cityId) ->
  cities = {
    "kc": {id:"kc", name:"kc", x:-1200, y:1040, scale:36000},
    "sl": {id:"sl", name:"st_louis", x:1, y:1, scale:1},
    "dn": {id:"dn", name:"denver", x:1, y:1, scale:1},
    "oc": {id:"oc", name:"ok_city", x:0, y:0, scale:1}
  }

  data = cities[cityId]

  city_view = new CityView data.name, data.x, data.y, data.scale
  city_view.display_city()

tract_ratio = (tract) ->
  if tract.P003001 > 20
    tract.P003003 / tract.P003001
  else
    0

difference_between = (tract_a, tract_b) ->
  ratio_a = tract_ratio(tract_a)
  ratio_b = tract_ratio(tract_b)
  Math.abs(ratio_b - ratio_a)

edge = (a, b) ->
  dx = (a.x - b.x)
  dy = (a.y - b.y)
  diff = difference_between(a.tract_data, b.tract_data) * 100
  e = {source: a, target:b, distance: Math.sqrt(dx * dx + dy * dy) + diff}
  #e = {source: a, target:b, distance: 1}
  e

class CityView
  constructor: (@name, @x, @y, @scale) ->
    @width = 900
    @height = 900
    @csv_data = {}
    @color = null


    @vis = d3.select("#vis-svg").remove()

    @vis = d3.select("#vis")
      .append("svg:svg")
      .attr("id", "vis-svg")
      .attr("width", @width)
      .attr("height", @height)

    @vis.append("svg:rect")
      .attr("width", @width)
      .attr("height", @height)

  setup_data: (csv) =>
    for tract in csv
      @csv_data[tract.GEOID] = tract

    max_pop = d3.max(csv, (d) -> tract_ratio(d))
    min_pop = d3.min(csv, (d) -> tract_ratio(d))
    @color = d3.scale.linear().range(["#F5F5F5", "#303030"]).domain([min_pop, max_pop])

  color_for: (data) =>
    @color(tract_ratio(data))

  display_city: () =>
    xy = d3.geo.albersUsa().translate([@x,@y]).scale(@scale)
    path = d3.geo.path().projection(xy)
    force = d3.layout.force().size([@width, @height])

    d3.csv "data/cities/#{@name}_race.csv", (csv) =>
      @setup_data(csv)
      d3.json "data/cities/#{@name}_tracts.json", (tracts) =>
        nodes = []
        links = []

        tracts.features.forEach (d, i) =>
          centroid = path.centroid(d)
          centroid.x = centroid[0]
          centroid.y = centroid[1]
          centroid.feature = d
          centroid.tract_data = @csv_data[d.properties["GEOID10"]]
          nodes.push centroid

        d3.geom.delaunay(nodes).forEach (d) =>
          links.push(edge(d[0], d[1]))
          links.push(edge(d[1], d[2]))
          links.push(edge(d[2], d[0]))

        force
          .gravity(0)
          .nodes(nodes)
          .links(links)
          .linkDistance( (d) -> d.distance)
          .charge(-1)
          .friction(0.6)
          .start()

        link = @vis.selectAll("line")
          .data(links)
        .enter().append("svg:line")
          .attr("x1", (d) -> d.source.x)
          .attr("y1", (d) -> d.source.y)
          .attr("x2", (d) -> d.target.x)
          .attr("y2", (d) -> d.target.y)
          .attr("stroke", "#333")
          .attr("stroke-width", "0px")

        node = @vis.selectAll("g")
          .data(nodes)
        .enter().append("svg:g")
          .attr("transform", (d) -> "translate(#{-d.x},#{-d.y})")
          .call(force.drag)
        .append("svg:path")
          .attr("transform", (d) -> "translate(#{-d.x},#{-d.y})")
          .attr("d", (d) -> path(d.feature))
          .attr("fill-opacity", 1.0)
          .attr("fill", (d) => @color_for(d.tract_data))
          .attr("stroke", "#222")
          .attr("stroke-width", "0px")

        force.on "tick", (e) ->
          link.attr("x1", (d) -> d.source.x)
            .attr("y1", (d) -> d.source.y)
            .attr("x2", (d) -> d.target.x)
            .attr("y2", (d) -> d.target.y)

          node.attr("transform", (d) -> "translate(#{d.x},#{d.y})")



$ ->
  showCity("kc")