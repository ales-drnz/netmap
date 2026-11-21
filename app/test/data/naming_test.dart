import 'package:flutter_test/flutter_test.dart';
import 'package:netmap/data/naming.dart';

void main() {
  test('owner and type follow the person-type convention', () {
    expect(ownerOf('alice-pc'), 'alice');
    expect(typeOf('alice-pc'), DeviceType.pc);
    expect(ownerOf('alice-phone-work'), 'alice');
    expect(typeOf('bob-tablet'), DeviceType.tablet);
    expect(ownerOf('home-tv'), 'home');
    expect(typeOf('home-tv'), DeviceType.tv);
  });

  test('the type is found anywhere, the owner is the first non-type part', () {
    expect(typeOf('PC-Dave'), DeviceType.pc);
    expect(ownerOf('PC-Dave'), 'dave');
    expect(typeOf('LAPTOP-Erin'), DeviceType.laptop);
    expect(ownerOf('LAPTOP-Erin'), 'erin');
  });

  test('trailing digits are ignored when grouping', () {
    expect(ownerOf('carol2-pc'), 'carol');
    expect(ownerOf('carol-pc-2'), 'carol');
    expect(typeOf('ps5'), DeviceType.console);
  });

  test('synonyms and qualifiers', () {
    expect(typeOf('frank-iphone'), DeviceType.phone);
    expect(typeOf('lab-pi'), DeviceType.server);
    expect(typeOf('office-printer'), DeviceType.iot);
    expect(ownerOf('old-laptop'), isNull);
    expect(typeOf('nas'), DeviceType.server);
    expect(ownerOf('nas'), isNull);
    expect(typeOf('mystery'), isNull);
  });
}
