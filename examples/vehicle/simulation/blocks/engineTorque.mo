model EngineTorque
  annotation(Diagram(), Icon(graphics = {Line(points = {{-54.6218,-74.3697},{65.9664,-74.3697},{59.2437,-71.4286},{59.2437,-79.4118},{65.1261,-74.3697}}, rotation = 0, color = {0,0,255}, pattern = LinePattern.Solid, thickness = 0.25),Line(points = {{-55.042,-72.6891},{-55.042,44.1176},{-52.1008,34.4538},{-58.8235,34.4538},{-55.4622,43.6975}}, rotation = 0, color = {0,0,255}, pattern = LinePattern.Solid, thickness = 0.25),Line(points = {{-51.6807,-24.3697},{-39.0756,-11.7647},{-1.2605,0.840336},{24.3697,2.52101},{49.5798,1.2605},{60.084,-1.2605}}, rotation = 0, color = {0,0,255}, pattern = LinePattern.Solid, thickness = 0.25),Line(points = {{-52.1008,-83.6134},{16.3866,-88.2353},{68.9076,-92.8571}}, rotation = 0, color = {0,0,255}, pattern = LinePattern.Solid, thickness = 0.25)}));
  Modelica.Blocks.Logical.GreaterEqual greaterequal1 annotation(Placement(visible = true, transformation(origin = {-36.5546,-20.1681}, extent = {{-9.01578,-9.01578},{9.01578,9.01578}}, rotation = 0)));
  Modelica.Blocks.Sources.IntegerConstant integerconstant1(k = 1) annotation(Placement(visible = true, transformation(origin = {-39.0756,-82.3529}, extent = {{-7.45106,-7.45106},{7.45106,7.45106}}, rotation = 0)));
  Modelica.Blocks.Logical.And and1 annotation(Placement(visible = true, transformation(origin = {-0.420168,-8.82353}, extent = {{-8.19616,-8.19616},{8.19616,8.19616}}, rotation = 0)));
  Modelica.Blocks.Logical.Switch switch1 annotation(Placement(visible = true, transformation(origin = {28.1513,-9.2437}, extent = {{-8.19616,-8.19616},{8.19616,8.19616}}, rotation = 0)));
  Modelica.Blocks.Nonlinear.VariableLimiter variablelimiter1 annotation(Placement(visible = true, transformation(origin = {57.563,-51.6807}, extent = {{-8.19616,-8.19616},{8.19616,8.19616}}, rotation = 0)));
  Modelica.Blocks.Math.Gain maxTorqueScale(k = parMaxTorqueScale) annotation(Placement(visible = true, transformation(origin = {5.04202,30.2521}, extent = {{-6.1579,-6.1579},{6.1579,6.1579}}, rotation = 0)));
  Modelica.Blocks.Routing.Extractor extractor2 annotation(Placement(visible = true, transformation(origin = {-10.9244,-60.5042}, extent = {{-7.45106,-7.45106},{7.45106,7.45106}}, rotation = 0)));
  Modelica.Blocks.Routing.Extractor extractor1 annotation(Placement(visible = true, transformation(origin = {-15.1261,29.8319}, extent = {{-7.45106,-7.45106},{7.45106,7.45106}}, rotation = 0)));
  parameter Real parSpeedScale(start = 1, unit = "1") "" annotation(Placement(visible = true, transformation(origin = {71.2644,78.1609}, extent = {{-12,-12},{12,12}}, rotation = 0)));
  parameter Real parMaxTorqueScale(start = 1, unit = "1") "" annotation(Placement(visible = true, transformation(origin = {71.2644,78.1609}, extent = {{-12,-12},{12,12}}, rotation = 0)));
  parameter Real parDragTorqueScale(start = 1, unit = "1") "" annotation(Placement(visible = true, transformation(origin = {71.2644,78.1609}, extent = {{-12,-12},{12,12}}, rotation = 0)));
  parameter Real parStartSpeed(start = 1, unit = "1") "" annotation(Placement(visible = true, transformation(origin = {71.2644,78.1609}, extent = {{-12,-12},{12,12}}, rotation = 0)));
  parameter String maxTorqueFile(start = "") "" annotation(Placement(visible = true, transformation(origin = {71.2644,78.1609}, extent = {{-12,-12},{12,12}}, rotation = 0)));
  parameter String dragTorqueFile(start = "") "" annotation(Placement(visible = true, transformation(origin = {71.2644,78.1609}, extent = {{-12,-12},{12,12}}, rotation = 0)));
  Modelica.Blocks.Sources.Constant const(k = parStartSpeed) annotation(Placement(visible = true, transformation(origin = {-63.4453,-34.0336}, extent = {{-7.45106,-7.45106},{7.45106,7.45106}}, rotation = 0)));
  Modelica.Blocks.Math.Gain speedScale(k = 1 / parSpeedScale) annotation(Placement(visible = true, transformation(origin = {-62.5997,-60.5042}, extent = {{-5.59809,-5.59809},{5.59809,5.59809}}, rotation = 0)));
  Modelica.Blocks.Interfaces.RealOutput torque annotation(Placement(visible = true, transformation(origin = {86.9748,-35.7143}, extent = {{-12,-12},{12,12}}, rotation = 0), iconTransformation(origin = {86.9748,-35.7143}, extent = {{-12,-12},{12,12}}, rotation = 0)));
  Modelica.Blocks.Interfaces.RealOutput y annotation(Placement(visible = true, transformation(origin = {87.0617,14.91}, extent = {{-12,-12},{12,12}}, rotation = 0), iconTransformation(origin = {87.0617,14.91}, extent = {{-12,-12},{12,12}}, rotation = 0)));
  Modelica.Blocks.Interfaces.RealOutput realoutput1 annotation(Placement(visible = true, transformation(origin = {88.0669,-82.3613}, extent = {{-12,-12},{12,12}}, rotation = 0), iconTransformation(origin = {88.0669,-82.3613}, extent = {{-12,-12},{12,12}}, rotation = 0)));
  Modelica.Blocks.Interfaces.RealInput torqueDemand annotation(Placement(visible = true, transformation(origin = {-81.9328,-67.6471}, extent = {{-12,-12},{12,12}}, rotation = 0), iconTransformation(origin = {-81.9328,-67.6471}, extent = {{-12,-12},{12,12}}, rotation = 0)));
  Modelica.Blocks.Interfaces.RealInput speed annotation(Placement(visible = true, transformation(origin = {-80.2521,-12.6051}, extent = {{-12,-12},{12,12}}, rotation = 0), iconTransformation(origin = {-80.2521,-12.6051}, extent = {{-12,-12},{12,12}}, rotation = 0)));
  Modelica.Blocks.Interfaces.BooleanInput engineOn annotation(Placement(visible = true, transformation(origin = {-79.832,39.4958}, extent = {{-12,-12},{12,12}}, rotation = 0), iconTransformation(origin = {-79.832,39.4958}, extent = {{-12,-12},{12,12}}, rotation = 0)));
  Modelica.Blocks.Tables.CombiTable1Ds dragTorque(tableOnFile = true, fileName = dragTorqueFile, tableName = "dragTorque") annotation(Placement(visible = true, transformation(origin = {-34.874,-60.9244}, extent = {{-8.19616,-8.19616},{8.19616,8.19616}}, rotation = 0)));
  Modelica.Blocks.Tables.CombiTable1Ds maxTorque(tableOnFile = true, tableName = "maxTorque", fileName = maxTorqueFile) annotation(Placement(visible = true, transformation(origin = {-36.5438,30.6723}, extent = {{-7.45106,-7.45106},{7.45106,7.45106}}, rotation = 0)));
  Modelica.Blocks.Math.Gain minTorqueScale(k = parDragTorqueScale) annotation(Placement(visible = true, transformation(origin = {11.316,-60.084}, extent = {{-6.1579,-6.1579},{6.1579,6.1579}}, rotation = 0)));
equation
  connect(extractor2.y,minTorqueScale.u) annotation(Line(points = {{-2.72823,-60.5042},{6.30252,-60.5042},{6.30252,-60.084},{3.9265,-60.084}}));
  connect(minTorqueScale.y,switch1.u3) annotation(Line(points = {{18.0897,-60.084},{18.4874,-60.084},{18.4874,-15.8006},{18.3159,-15.8006}}));
  connect(minTorqueScale.y,variablelimiter1.limit2) annotation(Line(points = {{18.0897,-60.084},{47.8992,-60.084},{47.8992,-58.2376},{47.7276,-58.2376}}));
  connect(minTorqueScale.y,realoutput1) annotation(Line(points = {{18.0897,-60.084},{27.5035,-60.084},{27.5035,-82.3613},{88.0669,-82.3613}}));
  connect(maxTorque.y,extractor1.u) annotation(Line(points = {{-28.3476,30.6723},{-7.56303,30.6723},{-7.56303,29.8319},{-24.0674,29.8319}}));
  connect(speedScale.y,maxTorque.u) annotation(Line(points = {{-56.4418,-60.5042},{-53.3613,-60.5042},{-53.3613,29.8319},{-45.485,29.8319},{-45.485,30.6723}}));
  connect(dragTorque.y,extractor2.u) annotation(Line(points = {{-25.8582,-60.9244},{-24.7899,-60.9244},{-24.7899,-60.5042},{-19.8657,-60.5042}}));
  connect(speedScale.y,dragTorque.u) annotation(Line(points = {{-56.4418,-60.5042},{-44.958,-60.5042},{-44.958,-60.9244},{-44.7094,-60.9244}}));
  connect(y,maxTorqueScale.y) annotation(Line(points = {{87.0617,14.91},{67.2269,14.91},{67.2269,30.2521},{11.8157,30.2521}}));
  connect(engineOn,and1.u1) annotation(Line(points = {{-79.832,39.4958},{-17.2269,39.4958},{-17.2269,-8.82353},{-10.2556,-8.82353},{-10.2556,-8.82353}}));
  connect(greaterequal1.u1,speed) annotation(Line(points = {{-47.3735,-20.1681},{-78.9916,-20.1681},{-78.9916,-12.6051},{-80.2521,-12.6051}}));
  connect(speed,speedScale.u) annotation(Line(points = {{-80.2521,-12.6051},{-70.1681,-12.6051},{-70.1681,-58.8235},{-69.3174,-58.8235},{-69.3174,-60.5042}}));
  connect(torqueDemand,variablelimiter1.u) annotation(Line(points = {{-81.9328,-67.6471},{36.5546,-67.6471},{36.5546,-51.6807},{47.7276,-51.6807}}));
  connect(const.y,greaterequal1.u2) annotation(Line(points = {{-55.2492,-34.0336},{-51.6807,-34.0336},{-51.6807,-27.3807},{-47.3735,-27.3807}}));
  connect(extractor1.y,maxTorqueScale.u) annotation(Line(points = {{-6.92989,29.8319},{5.04202,29.8319},{5.04202,30.2521},{-2.34746,30.2521}}));
  connect(integerconstant1.y,extractor1.index) annotation(Line(points = {{-30.8795,-82.3529},{-19.7479,-82.3529},{-19.7479,20.8907},{-15.1261,20.8907}}));
  connect(extractor2.index,integerconstant1.y) annotation(Line(points = {{-10.9244,-69.4455},{-10.9244,-82.7731},{-30.8795,-82.7731},{-30.8795,-82.3529}}));
  connect(maxTorqueScale.y,switch1.u1) annotation(Line(points = {{11.8157,30.2521},{17.6471,30.2521},{17.6471,-2.68677},{18.3159,-2.68677}}));
  connect(variablelimiter1.y,torque) annotation(Line(points = {{66.5788,-51.6807},{77.3109,-51.6807},{77.3109,-51.6807},{86.5546,-51.6807}}));
  connect(variablelimiter1.limit1,switch1.y) annotation(Line(points = {{47.7276,-45.1237},{42.0168,-45.1237},{42.0168,-9.2437},{37.167,-9.2437}}));
  connect(and1.y,switch1.u2) annotation(Line(points = {{8.59561,-8.82353},{38.2353,-8.82353},{38.2353,-9.2437},{18.3159,-9.2437}}));
  connect(greaterequal1.y,and1.u2) annotation(Line(points = {{-26.6373,-20.1681},{-12.605,-20.1681},{-12.605,-15.3805},{-10.2556,-15.3805}}));
end EngineTorque;
