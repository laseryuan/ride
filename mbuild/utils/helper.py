import yaml
import io

def get_data():
    ret = None
    with io.open("mbuild.yml", 'r', encoding='utf-8') as f:
        ret = yaml.full_load(f)
    for arch in ret['ARCH']:
        arch['enable'] = arch.get('enable', True)
    return ret

def test_get_data(mocker):
    ret = get_data()
    assert "ARCH" in ret
