```js
// Example
struct Position {
    mut x Number
    mut y Number
}

struct Velocity {
    mut x Number
    mut y Number
}

struct HasSomeTag
struct SomeOtherTag
// registry world

var particle = Entity() // or world.entity()
particle.add(Position { x = 42, y = 45 })
// particle += Position { x = 42, y = 45 }
particle.add(Velocity { x = 10, y = 0 })

for entity in Position pos, Velocity vel {
    pos.x += vel.x
    pos.y += vel.y
}

for entity in Position pos, HasSomeTag, not SomeOtherTag {
    print pos.x + ", " + pos.y
}

for p, v in query<Position, Velocity> {
    p.x += v.x
    p.y += v.y
}

fn movement(p Position, v Velocity) {
    p.x += v.x
    p.y += v.y
}

fn movement(query Query<p Position, v Velocity>) {
    for p, v in query {
        p.x += v.x
        p.y += v.y
    }
}

query(fn(p Position, v Velocity) {
    p.x += v.x
})

@system
fn move(p Position, v Velocity) {
    
}


fn some_name with p Position, v Velocity {

}

fn move(q Query(p Position, v Velocity)) {
    for pos, vel in q {

    }
}

fn move() {
    for query(p Position, v Velocity) {
        
    }
}

fn move() {
    for registry.query(p Position, v Velocity) {
        
    }
}
```
