```js
// Example
component Position {
    var x: Number
    var y: Number
}

component Velocity {
    var x: Number
    var y: Number
}

component HasSomeProperty
component SomeOtherProperty
// registry world

var particle = Entity() // or world.entity()
particle.add(Position { x: 42, y: 45 })
particle.add(Velocity { x: 10, y: 0 })

for entity in Position pos, Velocity vel {
    pos.x += vel.x
    pos.y += vel.y
}

for entity in Position pos, HasSomeProperty, !SomeOtherProperty {
    print pos.x + ", " + pos.y
}
```
