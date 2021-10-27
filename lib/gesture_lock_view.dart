import 'dart:math';

import 'package:flutter/material.dart';

class GestureLockView extends StatefulWidget {
  //控件正方形边长
  final double size;
  //圆圈之间的间距
  final double gap;
  //多少个圆圈
  final double radiusWeight;
  //最少画几个点
  final int minPoints;
  //画完后的结果回调
  final Function(List<int> password)? onPassword;
  //不满足minPoints条件的回调
  final Function()? onError;
  //画完后立即清除连线
  final bool clearOnDone;
  //圈线的颜色
  final Color color;
  GestureLockView(
      {required this.size,
      required this.gap,
      this.onPassword,
      this.onError,
      this.clearOnDone = true,
      this.minPoints = 4,
        this.color = const Color(0xFF666666),
      this.radiusWeight = 3});

  @override
  State<StatefulWidget> createState() => GestureState();
}

class GestureState extends State<GestureLockView> {
  final List<Point> points = [];
  final List<Point> selectPoints = [];
  Offset? point;

  @override
  void initState() {
    super.initState();
    double radius = (widget.size - widget.gap * 2) / 3 / 2;
    double selectRadius = radius / widget.radiusWeight;
    for (int i = 0; i < 9; i++) {
      var column = i % 3;
      var row = i ~/ 3;
      var dx = radius + radius * column * 2 + widget.gap * column;
      var dy = radius + radius * row * 2 + widget.gap * row;
      var center = Offset(dx, dy);
      var point = Point(
          center: center, radius: radius, selectRadius: selectRadius, value: i);
      points.add(point);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.size,
      width: widget.size,
      child: GestureDetector(
        onPanDown: _onPanDown,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onPanCancel: _onPanCancel,
        child: CustomPaint(
          size: Size(widget.size, widget.size),
          painter: PointPainter(
              points: points,
              point: point,
              selectPoints: selectPoints,
              color: widget.color),
        ),
      ),
    );
  }

  void _onPanDown(DragDownDetails down) {
    selectPoints.clear();
    var position = down.localPosition;
    for (Point point in points) {
      if (point.isInCircle(position)) {
        if (!selectPoints.contains(point)) selectPoints.add(point);
      }
    }
    setState(() {
      point = position;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    var position = details.localPosition;
    for (Point point in points) {
      if (point.isInCircle(position)) {
        if (!selectPoints.contains(point)) selectPoints.add(point);
      }
    }
    setState(() {
      point = position;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (selectPoints.length < widget.minPoints) {
      widget.onError?.call();
    } else {
      widget.onPassword?.call(selectPoints.map((e) => e.value).toList());
    }
    setState(() {
      if(widget.clearOnDone)
        selectPoints.clear();
      point = null;
    });
  }

  void _onPanCancel() {
    selectPoints.clear();
    setState(() {
      point = null;
    });
  }
}

class PointPainter extends CustomPainter {
  final List<Point> points;
  final List<Point> selectPoints;
  final Paint godPaint = Paint();
  Offset? point;

  PointPainter(
      {required this.points,
      required this.selectPoints,
      this.point,
      required Color color}) {
    godPaint.color = color;
    godPaint.strokeWidth = 1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    //画初始的外圈圆
    godPaint.style = PaintingStyle.stroke;
    for (Point point in points) {
      canvas.drawCircle(point.center, point.radius, godPaint);
    }
    if (selectPoints.isEmpty) return;
    //画被选中的内圈圆
    godPaint.style = PaintingStyle.fill;
    for (Point point in selectPoints) {
      canvas.drawCircle(point.center, point.selectRadius, godPaint);
    }
    //计算两点之间是否有其他圆，如果有，需要将其插入两点之间
    List<Point> lines = [];
    Point first = selectPoints[0];
    lines.add(first);
    for (int i = 1; i < selectPoints.length; i++) {
      Point next = selectPoints[i];
      Offset dis = next.center - first.center;
      double dx = first.center.dx;
      double dy = first.center.dy;
      double threshold = first.radius * 4;
      if (dis.dx.abs() > threshold && dis.dy.abs() > threshold) {
        //对角
        dx = (first.center.dx + next.center.dx) / 2;
        dy = (first.center.dy + next.center.dy) / 2;
      } else if (dis.dx.abs() > threshold && dis.dy.abs() == 0) {
        //水平跨圆
        dx = (first.center.dx + next.center.dx) / 2;
      } else if (dis.dy.abs() > threshold && dis.dx.abs() == 0) {
        //垂直跨圆
        dy = (first.center.dy + next.center.dy) / 2;
      }
      Offset center = Offset(dx, dy);
      if (center != first.center)
        for (int i = 0; i < points.length; i++) {
          if (points[i].isInCircle(center)) {
            lines.add(points[i]);
            break;
          }
        }
      lines.add(next);
      first = next;
    }
    //开始画两圆之间的线
    Point start = lines[0];
    for (int i = 1; i < lines.length; i++) {
      Point end = lines[i];
      double distant = sqrt(pow(end.center.dx - start.center.dx, 2) +
          pow(end.center.dy - start.center.dy, 2));
      double distantDx = end.center.dx - start.center.dx;
      double distantDy = end.center.dy - start.center.dy;
      Offset pStart = Offset(
          start.center.dx + start.radius * distantDx / distant,
          start.center.dy + start.radius * distantDy / distant);
      Offset pEnd = Offset(end.center.dx - start.radius * distantDx / distant,
          end.center.dy - start.radius * distantDy / distant);
      canvas.drawLine(pStart, pEnd, godPaint);
      start = end;
    }
    //画最后一个圆和当前手指位置之间的线
    if (point != null && !start.isInCircle(point!)) {
      Offset end = point!;
      double distant = sqrt(
          pow(end.dx - start.center.dx, 2) + pow(end.dy - start.center.dy, 2));
      Offset pStart = Offset(
          start.center.dx + start.radius * (end.dx - start.center.dx) / distant,
          start.center.dy +
              start.radius * (end.dy - start.center.dy) / distant);
      canvas.drawLine(pStart, end, godPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class Point {
  final Offset center;
  final double radius;
  final double selectRadius;
  int value;

  bool isInCircle(Offset point) {
    if (pow(point.dx - center.dx, 2) + pow(point.dy - center.dy, 2) <=
        pow(radius, 2)) return true;
    return false;
  }

  Point(
      {required this.center,
      required this.radius,
      required this.selectRadius,
      required this.value});
}
