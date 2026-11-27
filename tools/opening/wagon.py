"""Build the original Route 9 wagon from metre-scale cross sections and an authored atlas."""

from math import cos, pi, sin, tau
from pathlib import Path
import sys

from wagon_atlas import REGIONS, SIZE, build_atlas

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/opening"
sys.path.insert(0, str(ROOT / "tools/cooler"))
import mesh as gltf

# The cooler writer is shared. These region bindings are local to this generator process.
gltf.REGIONS, gltf.SIZE = REGIONS, SIZE
Mesh = gltf.Mesh
AXLES = (-1.46, 1.36)
SIDES = (-1, 1)
SILL = .252
SECTIONS = [(-2.26,.77,.59),(-2.09,.835,.655),(-1.10,.875,.772),
            (-.78,.878,.821),(.86,.878,.811),(1.92,.856,.788),(2.16,.795,.736)]


def section(z):
    for (z0,x0,y0),(z1,x1,y1) in zip(SECTIONS,SECTIONS[1:]):
        if z <= z1:
            t = (z-z0)/(z1-z0)
            return x0+(x1-x0)*t, y0+(y1-y0)*t
    return SECTIONS[-1][1:]


def side_face(mesh, points, side, paint, coords=None):
    # In the z/y plane the supplied points face towards the negative x axis.
    if side > 0:
        points = points[::-1]
        if coords is not None:
            coords = coords[::-1]
    mesh.face(points,paint,coords)


def exterior():
    body = Mesh("Sheet metal, seals and exterior fittings")
    # Section-aligned hood, belt line and cargo deck.
    for (za,xa,ya),(zb,xb,yb) in zip(SECTIONS,SECTIONS[1:]):
        for sign in SIDES:
            side_face(body,[(sign*xa,ya-.052,za),(sign*xb,yb-.052,zb),
                            (sign*(xb-.045),yb,zb),(sign*(xa-.045),ya,za)],sign,"edge")
        if za < -1.10 or za >= 1.92:
            body.face([(-xa+.045,ya,za),(-xb+.045,yb,zb),(xb-.045,yb,zb),(xa-.045,ya,za)],"paint")
        else:
            # Close the door tops with narrow rails and leave the actual cabin open.
            for lo,hi in ((-1,-.91),(.91,1)):
                body.face([(lo*(xa-.045),ya,za),(lo*(xb-.045),yb,zb),
                           (hi*(xb-.045),yb,zb),(hi*(xa-.045),ya,za)],"paint")
    for side in SIDES:
        for low,high in [(-2.26,-1.85),(-1.07,.97),(1.75,2.16)]:
            spans = [low]+[z for z,_,_ in SECTIONS if low < z < high]+[high]
            for za,zb in zip(spans,spans[1:]):
                xa,ya = section(za)
                xb,yb = section(zb)
                side_face(body,[(side*xa,SILL,za),(side*xb,SILL,zb),
                    (side*xb,yb-.052,zb),(side*xa,ya-.052,za)],side,"paint")
        for axle in AXLES:
            arch = [(axle-.39*cos(i*pi/8), SILL+.392*sin(i*pi/8)) for i in range(9)]
            molding = [(axle-.418*cos(i*pi/8), SILL+.42*sin(i*pi/8)) for i in range(9)]
            for i, ((za,ya),(zb,yb)) in enumerate(zip(arch,arch[1:])):
                xa,top_a = section(za)
                xb,top_b = section(zb)
                side_face(body,[(side*xa,ya,za),(side*xb,yb,zb),(side*xb,top_b-.052,zb),
                                (side*xa,top_a-.052,za)],side,"paint",
                          [(i/8,1),((i+1)/8,1),((i+1)/8,0),(i/8,0)])
                ma,mb = molding[i],molding[i+1]
                side_face(body,[(side*xa,ya,za),(side*xb,yb,zb),
                                (side*(section(mb[0])[0]+.011),mb[1],mb[0]),
                                (side*(section(ma[0])[0]+.011),ma[1],ma[0])],side,"trim")
                body.face([(side*xa,ya,za),(side*.67,ya,za),(side*.67,yb,zb),(side*xb,yb,zb)] if side > 0 else
                          [(side*xb,yb,zb),(side*.67,yb,zb),(side*.67,ya,za),(side*xa,ya,za)],"rubber")
        body.box((side*.866,.294,-.044),(.028,.07,2.01),"sill")
        body.box((side*.876,.488,-.05),(.018,.049,1.94),"trim")
        for z in (-.64,.29,1.02):
            x,_ = section(z)
            body.box((side*(x+.006),.664,z),(.012,.19,.014),"sill")
        for z in (-.29,.67):
            body.box((side*.89,.712,z),(.029,.031,.124),"trim")
            body.box((side*.907,.722,z),(.008,.012,.091),"alloy")
        body.box((side*.849,1.019,-.846),(.13,.038,.055),"trim")
        body.box((side*.968,1.045,-.846),(.162,.085,.141),"paint")
        body.box((side*.968,1.045,-.770),(.135,.066,.015),"glass")
        for z in (-.37,1.56):
            body.box((side*.54,1.613,z),(.063,.098,.107),"trim")
        body.box((side*.54,1.668,.60),(.045,.039,2.10),"alloy")
    # Fender seams run from the cowl to the light housings.
    for side in SIDES:
        for (za,_,ya),(zb,_,yb) in zip(SECTIONS[:3],SECTIONS[1:3]):
            x = side*.668
            body.face([(x-.007,ya+.004,za),(x-.007,yb+.004,zb),
                       (x+.007,yb+.004,zb),(x+.007,ya+.004,za)],"sill")
    body.box((0,.438,-2.236),(1.55,.302,.08),"paint")
    body.box((0,.335,-2.249),(1.67,.114,.163),"trim")
    body.box((0,.38,-2.336),(1.52,.026,.014),"alloy")
    body.box((0,.526,-2.281),(.75,.14,.035),"grille")
    body.box((0,.282,2.17),(1.68,.132,.18),"trim")
    body.box((0,.32,2.265),(1.57,.037,.021),"alloy")
    body.box((0,.533,2.123),(1.595,.403,.073),"paint")
    body.box((0,.563,2.166),(1.21,.012,.018),"sill")
    body.box((0,.42,2.173),(.391,.154,.029),"trim")
    body.box((0,.416,2.191),(.295,.112,.014),"plate")
    for side in SIDES:
        body.box((side*.588,.523,-2.278),(.358,.183,.032),"trim")
        body.box((side*.555,.535,-2.301),(.271,.119,.024),"head")
        body.box((side*.718,.524,-2.301),(.061,.117,.024),"amber")
        body.box((side*.710,.574,2.179),(.205,.259,.041),"trim")
        body.box((side*.710,.61,2.206),(.164,.148,.026),"tail")
        body.box((side*.710,.517,2.206),(.164,.041,.026),"amber")
        body.box((side*.710,.481,2.207),(.164,.026,.026),"head")
    body.box((0,.217,-.03),(1.32,.079,3.80),"rubber")
    return body


def cabin():
    frames = Mesh("Roof and window frames")
    front = Mesh("Windshield", 1)
    other = Mesh("Side and cargo glazing", 2)
    # Points are lower glass corners then roof joints along each belt line.
    lows = [(-1.092,.777),(-.049,.818),(.86,.809),(2.093,.763)]
    highs = [(-.575,1.514),(-.049,1.558),(.86,1.554),(1.829,1.467)]

    def frame(mesh, a,b,c,d):
        for u0,u1,v0,v1 in [(0,1,0,.055),(0,1,.935,1),(0,.069,.055,.935),(.931,1,.055,.935)]:
            def point(u,v):
                return tuple((1-v)*((1-u)*a[i]+u*b[i])+v*((1-u)*d[i]+u*c[i]) for i in range(3))
            frames.face([point(u0,v0),point(u1,v0),point(u1,v1),point(u0,v1)],"trim")
        def inset(u,v):
            return tuple((1-v)*((1-u)*a[i]+u*b[i])+v*((1-u)*d[i]+u*c[i]) for i in range(3))
        mesh.face([inset(.069,.055),inset(.931,.055),inset(.931,.935),inset(.069,.935)],"glass")

    low = lambda side,i: (side*(.831 if i < 3 else .785),lows[i][1],lows[i][0])
    high = lambda side,i: (side*(.728 if i < 3 else .688),highs[i][1],highs[i][0])
    frame(front,low(1,0),low(-1,0),high(-1,0),high(1,0))
    frame(other,low(-1,3),low(1,3),high(1,3),high(-1,3))
    for i in range(3):
        for side in SIDES:
            corners = [low(side,i),low(side,i+1),high(side,i+1),high(side,i)]
            frame(other,*corners[::(-1 if side > 0 else 1)])
        za,ya = highs[i]
        zb,yb = highs[i+1]
        xa,xb = abs(high(1,i)[0]),abs(high(1,i+1)[0])
        frames.face([(-xa,ya,za),(-xb,yb,zb),(xb,yb,zb),(xa,ya,za)],"vinyl")
        frames.face([(-xa,ya+.055,za),(-xb,yb+.055,zb),(xb,yb+.055,zb),(xa,ya+.055,za)],"edge")
        for side in SIDES:
            side_face(frames,[(side*xa,ya,za),(side*xb,yb,zb),(side*xb,yb+.055,zb),
                             (side*xa,ya+.055,za)],side,"paint")
    frames.face([(-.688,1.467,1.829),(.688,1.467,1.829),(.688,1.522,1.829),(-.688,1.522,1.829)],"paint")
    frames.face([(.728,1.514,-.575),(-.728,1.514,-.575),(-.728,1.569,-.575),(.728,1.569,-.575)],"paint")
    return frames, front, other


def wheels():
    wheel = Mesh("Tire and stamped steel wheel")
    profile = [(-.10,.255,"rubber"),(-.075,.307,"rubber"),(-.048,.329,"rubber"),
               (.063,.329,"rubber"),(.104,.308,"rubber"),(.121,.226,"rubber"),
               (.123,.193,"trim"),(.132,.174,"alloy"),(.111,.132,"alloy"),(.128,.070,"alloy")]
    sides = 14
    def point(x,r,i):
        angle = tau*i/sides
        return x,cos(angle)*r,sin(angle)*r
    for (xa,ra,_),(xb,rb,paint) in zip(profile,profile[1:]):
        for i in range(sides):
            wheel.face([point(xa,ra,i+1),point(xb,rb,i+1),point(xb,rb,i),point(xa,ra,i)],paint,
                       [(0,1),(1,1),(1,0),(0,0)])
    for i in range(sides):
        wheel.face([(.129,0,0),point(.128,.070,i),point(.128,.070,i+1)],"alloy",[(.5,.5),(0,0),(1,0)])
        wheel.face([(-.10,0,0),point(-.10,.255,i+1),point(-.10,.255,i)],"rubber",[(.5,.5),(0,0),(1,0)])
    for i in range(7):
        a = i*tau/7
        wheel.face([(.123,.144*cos(a-.13),.144*sin(a-.13)),(.123,.165*cos(a-.13),.165*sin(a-.13)),
                    (.123,.165*cos(a+.13),.165*sin(a+.13)),(.123,.144*cos(a+.13),.144*sin(a+.13))],"trim")
    return wheel


def interior():
    fittings = Mesh("Vinyl dash, upholstery and door cards")
    dashboard(fittings)
    fittings.box((0,.31,.29),(1.55,.08,2.62),"rubber")
    for side in SIDES:
        fittings.box((side*.795,.727,.373),(.081,.194,2.99),"vinyl")
        fittings.box((side*.746,.749,.010),(.067,.045,.53),"trim")
        fittings.box((side*.39,.501,.314),(.49,.15,.58),"fabric")
        fittings.box((side*.39,.791,.623),(.47,.596,.143),"fabric")
        fittings.box((side*.39,1.131,.65),(.255,.150,.139),"vinyl")
    fittings.box((0,.50,1.38),(1.43,.17,.55),"fabric")
    fittings.box((0,.753,1.655),(1.43,.48,.17),"fabric")
    fittings.box((.10,.48,-.003),(.30,.28,.79),"vinyl")
    fittings.box((.075,.669,-.21),(.038,.202,.041),"trim")
    fittings.box((.075,.772,-.211),(.071,.063,.061),"rubber")
    markings = Mesh("Lit instrument printing", 3)
    markings.front(-.604,.864,-.135,1.018,-.473,"gauges")
    markings.front(-.030,.730,.239,.803,-.370,"console")
    steer = steering()
    needle = Mesh("Speed needle", 3)
    needle.box((.031,0,0),(.068,.0045,.003),"amber")
    needle.box((0,0,.004),(.022,.021,.005),"trim")
    return fittings, markings, steer, needle


def dashboard(fittings):
    def band(x0, x1, high, low, material):
        ya,za = high
        yb,zb = low
        fittings.face([(x0,yb,zb),(x1,yb,zb),(x1,ya,za),(x0,ya,za)],material)

    band(-.81,.81,(.877,-1.048),(.911,-.512),"vinyl")
    lip = [(.911,-.512),(.905,-.434),(.881,-.366),(.842,-.369)]
    for x0,x1 in ((-.81,-.626),(-.114,.81)):
        for high,low in zip(lip,lip[1:]):
            band(x0,x1,high,low,"vinyl")
    band(-.81,.81,lip[-1],(.726,-.396),"vinyl")
    band(-.81,.81,(.726,-.396),(.588,-.467),"trim")

    def bevel(x0,y0,x1,y1,z,cut):
        return [(x0+cut,y0,z),(x1-cut,y0,z),(x1,y0+cut,z),(x1,y1-cut,z),
                (x1-cut,y1,z),(x0+cut,y1,z),(x0,y1-cut,z),(x0,y0+cut,z)]

    # Padded instrument hood wraps around an open, bevelled recess.
    back = bevel(-.621,.850,-.121,.962,-.649,.027)
    shoulder = bevel(-.644,.827,-.098,1.068,-.415,.027)
    brow = bevel(-.632,.838,-.108,1.051,-.357,.021)
    inside = bevel(-.604,.864,-.135,1.018,-.475,.014)
    for i in range(len(brow)):
        j = (i+1)%len(brow)
        fittings.face([back[i],back[j],shoulder[j],shoulder[i]],"vinyl")
        fittings.face([shoulder[i],shoulder[j],brow[j],brow[i]],"vinyl")
        fittings.face([brow[i],brow[j],inside[j],inside[i]],"trim")
    fittings.box((-.38,.817,-.414),(.113,.086,.146),"trim")

    # Two bevelled vents above the receiver, and a smaller matching door vent.
    for x, width, depth in ((-.735,.124,-.361),(.015,.137,-.365),(.185,.137,-.365)):
        fittings.box((x,.834,depth),(width+.022,.081,.030),"trim")
        fittings.box((x,.834,depth+.014),(width,.063,.009),"rubber")
        for y in (.815,.829,.844,.858):
            fittings.box((x,y,depth+.021),(width-.016,.005,.009),"trim")
        fittings.box((x,.836,depth+.027),(.008,.055,.006),"vinyl")
    fittings.box((.105,.765,-.398),(.302,.106,.052),"rubber")
    for x in (-.015,.233):
        fittings.box((x,.763,-.367),(.043,.047,.029),"trim")
        fittings.box((x,.763,-.349),(.027,.028,.009),"vinyl")
    fittings.box((.513,.790,-.391),(.474,.130,.032),"rubber")
    fittings.box((.513,.790,-.378),(.462,.118,.016),"vinyl")
    fittings.box((.518,.823,-.368),(.061,.017,.010),"trim")
    for x in (-.45,.42):
        for i in range(3):
            fittings.box((x,.889+i*.0018,-.923+i*.029),(.269,.004,.008),"rubber")


def steering():
    art = Mesh("Round padded steering wheel")
    for i in range(18):
        for j in range(5):
            def at(ring,arc):
                a,b = tau*ring/18, tau*arc/5
                r = .167 + .020*cos(b)
                return (cos(a)*r,sin(a)*r,.020*sin(b))
            material = "vinyl" if i not in (4,11,12) else "trim"
            art.face([at(i,j),at(i+1,j),at(i+1,j+1),at(i,j+1)],material)
    for side in SIDES:
        a = side*.049
        b = side*.159
        art.face([(a,-.021,.012),(b,-.055,.006),(b,-.017,.006),(a,.034,.02)],"trim")
        art.box((side*.13,-.035,.004),(.046,.035,.027),"rubber")
    outline = [(-.078,-.044),(.078,-.044),(.088,-.018),(.068,.046),(-.068,.046),(-.088,-.018)]
    for i in range(len(outline)):
        x,y = outline[i]
        xx,yy = outline[(i+1)%len(outline)]
        art.face([(0,0,.045),(x,y,.045),(xx,yy,.045)],"vinyl",[(.5,.5),(0,1),(1,1)])
        art.face([(x,y,.045),(x,y,.003),(xx,yy,.003),(xx,yy,.045)],"trim")
    return art


def main():
    pbr = {"baseColorTexture":{"index":0},"metallicFactor":.02,"roughnessFactor":.78}
    scene = gltf.Scene()
    scene.data["asset"]["generator"] = "Route 9 original wagon, tools/opening/wagon.py"
    scene.data["images"][0]["uri"] = "route9_wagon_atlas.png"
    scene.data["materials"] = [
        {"name":"Wagon sheet metal and trim","pbrMetallicRoughness":pbr,"doubleSided":True},
        {"name":"Windshield","pbrMetallicRoughness":dict(pbr,baseColorFactor=[.64,.76,.80,.11],roughnessFactor=.45),
         "alphaMode":"BLEND","doubleSided":True},
        {"name":"Cargo and side glass","pbrMetallicRoughness":dict(pbr,baseColorFactor=[.63,.75,.77,.74],roughnessFactor=.49),
         "alphaMode":"BLEND","doubleSided":True},
        {"name":"Instrument backlight","pbrMetallicRoughness":pbr,
         "emissiveTexture":{"index":0},"emissiveFactor":[.55,.44,.23]},
    ]
    scene.data["samplers"][0]["minFilter"] = 9984
    outside = [exterior(), *cabin()]
    cabin_art, markings, steer, needle = interior()
    wheel = wheels()
    for part in outside:
        scene.node(part.name,scene.mesh(part))
    scene.node("DashboardAndUpholstery",scene.mesh(cabin_art))
    scene.node(markings.name,scene.mesh(markings))
    scene.node("SteeringWheel",scene.mesh(steer),position=(-.38,.845,-.322))
    scene.node("SpeedNeedle",scene.mesh(needle),position=(-.470,.940,-.468))
    wheel_id = scene.mesh(wheel)
    for side in SIDES:
        for i,z in enumerate(AXLES):
            scene.node(f"RoadWheel_{side}_{i}",wheel_id,position=(side*.774,.33,z),yaw=pi if side < 0 else 0)
    OUT.mkdir(parents=True,exist_ok=True)
    build_atlas().save(OUT / "route9_wagon_atlas.png")
    scene.save(OUT / "route9_wagon.glb")
    parts = outside+[cabin_art,markings,steer,needle,wheel]
    unique = sum(len(part.indices)//3 for part in parts)
    print(f"Wagon: {unique:,} unique triangles, {unique+len(wheel.indices):,} per assembled wagon, "
          f"{len(parts)} meshes, {len(scene.data['materials'])} materials, 4 references to one wheel mesh")
    for part in parts:
        print(f"  {part.name}: {len(part.indices)//3}")


if __name__ == "__main__":
    main()
