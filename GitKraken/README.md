# GitCracken

**This method only applies to the On-Premise version of GitKraken.** [Click here to download](https://www.gitkraken.com/download-on-premise-serverless)

## Generate Public and Private Keys

```bash
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:1024 -out private_key.pem
openssl rsa -in private_key.pem -pubout -out public_key.pem
```

## Unpack the ASAR Archive

- `mkdir GK`
- `npm install -g asar`
- `cp GitKraken/app.asar GK/app.asar`
- `cp -r GitKraken/app.asar.unpacked GK/app.asar.unpacked`

## Replace the Public Key

```bash
export PUBLIC_KEY_ORIG=LS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS0KTUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FROEFNSUlCQ2dLQ0FRRUF3T29KZ2xHTk9URlF4eG9aU1ZqMApsc0JJRjRiYlcrcDVjM0lzUE9JUk9jdHpyT1NPTkZFQldWVzQydVF6cGNhTGl6Vms5cDdsRnRaTWdtNE1aSEY2CjJQc0d3dXcwZEpXWFlpOEhqUFhwbjltQklrQTRqZ292ZjNOVVN2Yzk5Zm9yaDlUeU4wV3dNaW9TNjR6Q1g5ejIKMUtmdWdFTWNCZlVOdDMxbWtkbzk1U3NXQmh0T05odnhFdCtsS3g2VDVMSjBhZGJ3cWRrY29QNVRteFNSeG1HMQpEdWViZmZMcFJZSXFkK2RSSWZwc2d6L1k5Y3BxODNqT05RMS9GTHh6NlZNNVhNN0ExT1hrVkRyeVRaNlFlMTN3CmlxUDhDZ1VPaVNWcld3QXNIQW9BMGRXWmx4YjVMMkVaaTNMeE5FUW01dFptWmU2SkY2QmRlbzEvV1ZlajhFRGgKUVFJREFRQUIKLS0tLS1FTkQgUFVCTElDIEtFWS0tLS0t
find GK/app/ -name '*.js' -exec sed -i '' 's/${PUBLIC_KEY_ORIG}/$(base64 -i public_key.pem)/' {} \;
```

## Repack `app.asar` and Replace the Original

- `asar pack GK/app app.asar`
- Replace the ASAR archive in the original application with the generated `app.asar`.

## Create a New License File

- `python3 gen_license.py --out license.json --mode full`

## Encrypt the License File

- `python3 enc_json.py encode license.json --private-key private_key.pem license.dat`
- Place the generated `license.dat` file in the `$HOME/.gitkraken/` directory.